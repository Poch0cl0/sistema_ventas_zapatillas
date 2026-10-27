import { ConfigService } from '@nestjs/config';
import { Timestamp, type Firestore } from 'firebase-admin/firestore';
import { DemoGatewayService, demoGatewayEnabled } from './demo-gateway.js';

function fixture(
  options: { expired?: boolean; manual?: boolean; consumed?: boolean } = {},
) {
  const docs = new Map<string, Record<string, any>>([
    [
      'orders/order1',
      {
        userId: 'client',
        totalCents: 25990,
        isSimulation: false,
        status: 'PENDIENTE_PAGO',
        paymentStatus: 'PENDIENTE',
        fulfillmentStatus: 'SIN_INICIAR',
        reservationState: options.consumed ? 'CONSUMED' : 'ACTIVE',
        reservationExpiresAt: Timestamp.fromMillis(
          Date.now() + (options.expired ? -1000 : 86400000),
        ),
        currentPaymentId: options.manual ? 'manual1' : null,
        items: [{ productId: 'shoe', size: '40', quantity: 2 }],
      },
    ],
    ['inventory/shoe_40', { available: 8, reserved: 2 }],
  ]);
  let count = 0;
  const reference = (path: string) => ({
    path,
    id: path.split('/').at(-1),
    get: async () => snapshot(path),
  });
  const snapshot = (path: string) => ({
    id: path.split('/').at(-1),
    exists: docs.has(path),
    data: () => docs.get(path),
  });
  const firestore = {
    collection: (name: string) => ({
      doc: (id = `movement${++count}`) => reference(`${name}/${id}`),
    }),
    runTransaction: async (
      callback: (transaction: any) => Promise<unknown>,
    ) => {
      const writes: (() => void)[] = [];
      const result = await callback({
        get: async (ref: any) => snapshot(ref.path),
        getAll: async (...refs: any[]) => refs.map((ref) => snapshot(ref.path)),
        create: (ref: any, data: any) =>
          writes.push(() => {
            docs.set(ref.path, data);
          }),
        update: (ref: any, data: any) =>
          writes.push(() => {
            docs.set(ref.path, { ...docs.get(ref.path), ...data });
          }),
      });
      writes.forEach((write) => write());
      return result;
    },
  } as unknown as Firestore;
  const service = new DemoGatewayService(
    firestore,
    new ConfigService({ DEMO_GATEWAY_ENABLED: 'true' }),
  );
  return { service, docs };
}

describe('Pasarela local sin API keys', () => {
  it('está apagada por defecto en producción y puede desactivarse en desarrollo', () => {
    expect(
      demoGatewayEnabled(new ConfigService({ NODE_ENV: 'production' })),
    ).toBe(false);
    expect(
      demoGatewayEnabled(new ConfigService({ DEMO_GATEWAY_ENABLED: 'false' })),
    ).toBe(false);
    expect(
      demoGatewayEnabled(
        new ConfigService({
          DEMO_GATEWAY_ENABLED: 'true',
          NODE_ENV: 'production',
        }),
      ),
    ).toBe(true);
  });
  it('rechaza pedidos ajenos, vencidos y con pago manual', async () => {
    await expect(fixture().service.checkout('order1', 'other')).rejects.toThrow(
      'no encontrado',
    );
    await expect(
      fixture({ expired: true }).service.checkout('order1', 'client'),
    ).rejects.toThrow('venció');
    await expect(
      fixture({ manual: true }).service.checkout('order1', 'client'),
    ).rejects.toThrow('manual');
  });
  it('crea una sola sesión, toma el importe del servidor y marca la simulación', async () => {
    const { service, docs } = fixture();
    const first = await service.checkout('order1', 'client');
    expect(first).toMatchObject({
      amountCents: 25990,
      currency: 'PEN',
      testMode: true,
      provider: 'LOCAL_DEMO',
    });
    expect(await service.checkout('order1', 'client')).toEqual(first);
    expect(docs.get('orders/order1')!.isSimulation).toBe(true);
    expect(
      [...docs.keys()].filter((k) => k.startsWith('demo_checkouts/')),
    ).toHaveLength(1);
  });
  it('pendiente y rechazo no consumen stock; luego permite aprobar una sola vez', async () => {
    const { service, docs } = fixture();
    const { id } = await service.checkout('order1', 'client');
    await service.confirm(id, 'PENDING', 'client');
    await service.confirm(id, 'REJECTED', 'client');
    expect(docs.get('inventory/shoe_40')).toEqual({
      available: 8,
      reserved: 2,
    });
    await expect(service.confirm(id, 'APPROVED', 'other')).rejects.toThrow(
      'no encontrado',
    );
    expect((await service.confirm(id, 'APPROVED', 'client')).status).toBe(
      'APPROVED',
    );
    expect(docs.get('inventory/shoe_40')).toMatchObject({
      available: 8,
      reserved: 0,
    });
    expect(docs.get('orders/order1')).toMatchObject({
      paymentStatus: 'SIMULADO',
      isSimulation: true,
      fulfillmentStatus: 'PREPARANDO',
      reservationState: 'CONSUMED',
    });
    await service.confirm(id, 'APPROVED', 'client');
    await service.confirm(id, 'REJECTED', 'client');
    expect(docs.get('inventory/shoe_40')).toMatchObject({
      available: 8,
      reserved: 0,
    });
    expect(
      [...docs.keys()].filter((k) => k.startsWith('inventory_movements/')),
    ).toHaveLength(1);
  });
  it('no liquida un pedido cancelado ni con importe alterado', async () => {
    const { service, docs } = fixture();
    const { id } = await service.checkout('order1', 'client');
    docs.get('orders/order1')!.totalCents = 1;
    await expect(service.confirm(id, 'APPROVED', 'client')).rejects.toThrow(
      'cambió',
    );
    docs.get('orders/order1')!.reservationState = 'RELEASED';
    await expect(service.confirm(id, 'APPROVED', 'client')).rejects.toThrow(
      'reserva activa',
    );
    expect(docs.get('inventory/shoe_40')).toEqual({
      available: 8,
      reserved: 2,
    });
  });
  it('rechaza la confirmación si la reserva vence después de abrir el checkout', async () => {
    const { service, docs } = fixture();
    const { id } = await service.checkout('order1', 'client');
    docs.get('orders/order1')!.reservationExpiresAt = Timestamp.fromMillis(
      Date.now() - 1000,
    );
    await expect(service.confirm(id, 'APPROVED', 'client')).rejects.toThrow(
      'venció',
    );
    expect(docs.get('inventory/shoe_40')).toEqual({
      available: 8,
      reserved: 2,
    });
    expect((await service.find(id, 'client')).status).toBe('CREATED');
  });
});
