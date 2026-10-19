import { Test } from '@nestjs/testing';
import type { INestApplication } from '@nestjs/common';
import { initializeApp, deleteApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import request from 'supertest';
import { AppModule } from '../src/app.module.js';
import {
  FIREBASE_APP,
  FIREBASE_AUTH,
  FIREBASE_FIRESTORE,
} from '../src/firebase/firebase.providers.js';
import { CloudinaryService } from '../src/cloudinary/cloudinary.service.js';
import { configureSwagger } from '../src/config/swagger.js';

vi.hoisted(() => {
  process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8089';
  process.env.FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9098';
  process.env.FIREBASE_PROJECT_ID = 'snakerstore-e74cd';
  process.env.FIREBASE_SERVICE_ACCOUNT = './unused-integration.json';
});

describe('Integración HTTP con Auth y Firestore Emulator', () => {
  const firebase = initializeApp(
    {
      projectId: 'demo-sneakerstore',
    },
    'commerce-integration',
  );
  const firestore = getFirestore(firebase);
  let app: INestApplication;
  let adminToken: string;
  let clientToken: string;
  let otherToken: string;
  let clientUid: string;
  let productId: string;
  let zoneId: string;
  let orderId: string;
  let paymentId: string;
  const http = () => app.getHttpServer();

  async function account(role: string) {
    const response = await fetch(
      'http://127.0.0.1:9098/identitytoolkit.googleapis.com/v1/accounts:signUp?key=emulator-only',
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email: `${crypto.randomUUID()}@example.invalid`,
          password: 'Only-emulator-123!',
          returnSecureToken: true,
        }),
      },
    );
    if (!response.ok) throw new Error('No se pudo crear la cuenta emulada.');
    const data = await response.json();
    await firestore
      .collection('users')
      .doc(data.localId)
      .set({ role, name: 'Usuario de integración' });
    return { token: data.idToken as string, uid: data.localId as string };
  }

  beforeAll(async () => {
    if (firestore.projectId !== 'demo-sneakerstore')
      throw new Error('Solo se permiten pruebas en el proyecto demo.');
    const module = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(FIREBASE_APP)
      .useValue(firebase)
      .overrideProvider(FIREBASE_AUTH)
      .useValue(getAuth(firebase))
      .overrideProvider(FIREBASE_FIRESTORE)
      .useValue(firestore)
      .overrideProvider(CloudinaryService)
      .useValue({
        upload: vi.fn(async () => ({
          secure_url: 'https://example.invalid/product.jpg',
          public_id: 'emulator/photo',
        })),
        cleanup: vi.fn(),
      })
      .compile();
    app = module.createNestApplication();
    configureSwagger(app);
    await app.init();
    adminToken = (await account('ADMINISTRADOR')).token;
    const client = await account('CLIENTE');
    clientToken = client.token;
    clientUid = client.uid;
    otherToken = (await account('CLIENTE')).token;
  });
  afterAll(async () => {
    if (app) await app.close();
    await firestore.terminate();
    await deleteApp(firebase);
  });

  it('verifica tokens reales del emulador, roles y Swagger', async () => {
    await request(http()).get('/docs-json').expect(200);
    const me = await request(http())
      .get('/auth/me')
      .set('Authorization', `Bearer ${adminToken}`)
      .expect(200);
    expect(me.body.role).toBe('ADMINISTRADOR');
    await request(http()).get('/admin/products').expect(401);
    await request(http())
      .get('/admin/products')
      .set('Authorization', `Bearer ${clientToken}`)
      .expect(403);
  });

  it('crea producto e inventario mediante los endpoints anteriores', async () => {
    const created = await request(http())
      .post('/admin/products')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({
        name: 'Producto de integración',
        description: 'Solo emulador',
        priceCents: 10000,
        category: 'Urbano',
        brand: 'Prueba',
        active: true,
      })
      .expect(201);
    productId = created.body.id;
    await request(http())
      .post('/admin/inventory')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({
        productId,
        size: '40',
        quantity: 30,
        reason: 'Prueba de integración',
      })
      .expect(201);
    await request(http()).get(`/products/${productId}`).expect(200);
    await request(http())
      .patch(`/admin/products/${productId}`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ priceCents: 12000 })
      .expect(200);
    await request(http())
      .patch(`/admin/inventory/${productId}_40`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ delta: 1, reason: 'Reposición emulada' })
      .expect(200);
  });

  it('integra fotos sin usar Cloudinary real', async () => {
    const png = Buffer.from(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a2ioAAAAASUVORK5CYII=',
      'base64',
    );
    await request(http())
      .post(`/admin/products/${productId}/images`)
      .set('Authorization', `Bearer ${adminToken}`)
      .attach('files', png, { filename: 'photo.png', contentType: 'image/png' })
      .expect(201);
    const product = await request(http())
      .get(`/products/${productId}`)
      .expect(200);
    expect(product.body.images).toHaveLength(1);
  });

  it('crea zonas, tarifas y configuración desde sus endpoints', async () => {
    const zone = await request(http())
      .post('/admin/delivery-zones')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ name: 'Zona emulada', feeCents: 800, active: true })
      .expect(201);
    zoneId = zone.body.id;
    await request(http()).get('/delivery-zones').expect(200);
    await request(http())
      .put('/admin/store-settings')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({
        storeName: 'Tienda emulada',
        pickup: {
          enabled: true,
          address: 'Dirección emulada 123',
          instructions: 'Presentar pedido',
          openingHours: '10:00 a 18:00',
        },
        paymentMethods: [
          {
            method: 'YAPE',
            enabled: true,
            holderName: 'Prueba',
            phone: '900000000',
          },
        ],
        publicNotes: 'Datos de prueba',
      })
      .expect(200);
    await request(http()).get('/store-settings').expect(200);
  });

  const checkout = (
    key: string,
    items = [{ productId, size: '40', quantity: 2 }],
    pickup = false,
  ) =>
    request(http())
      .post('/orders')
      .set('Authorization', `Bearer ${clientToken}`)
      .set('Idempotency-Key', key)
      .send({
        items,
        delivery: pickup
          ? {
              type: 'PICKUP',
              recipientName: 'Cliente emulado',
              phone: '900000000',
            }
          : {
              type: 'DELIVERY',
              recipientName: 'Cliente emulado',
              phone: '900000000',
              zoneId,
              address: 'Dirección del cliente 123',
            },
      });
  const stock = async (size = '40') =>
    (
      await firestore.collection('inventory').doc(`${productId}_${size}`).get()
    ).data()!;

  it('crea un pedido con precios del servidor, delivery y reserva de 24 h', async () => {
    const response = await checkout('checkout-delivery-001').expect(201);
    orderId = response.body.id;
    expect(response.body.subtotalCents).toBe(24000);
    expect(response.body.deliveryFeeCents).toBe(800);
    expect(response.body.totalCents).toBe(24800);
    expect(
      Date.parse(response.body.reservationExpiresAt) -
        Date.parse(response.body.createdAt),
    ).toBe(86400000);
    expect((await stock()).available).toBe(29);
    expect((await stock()).reserved).toBe(2);
    const repeated = await checkout('checkout-delivery-001').expect(201);
    expect(repeated.body.id).toBe(orderId);
    expect((await stock()).reserved).toBe(2);
    await checkout('checkout-delivery-001', [
      { productId, size: '40', quantity: 1 },
    ]).expect(409);
  });

  it('no permite precios manipulados, falta de clave ni direcciones incompletas', async () => {
    const valid = {
      items: [{ productId, size: '40', quantity: 1 }],
      delivery: {
        type: 'PICKUP',
        recipientName: 'Cliente',
        phone: '900000000',
      },
    };
    await request(http())
      .post('/orders')
      .set('Authorization', `Bearer ${clientToken}`)
      .send(valid)
      .expect(400);
    await request(http())
      .post('/orders')
      .set('Authorization', `Bearer ${clientToken}`)
      .set('Idempotency-Key', 'malicious-price')
      .send({ ...valid, totalCents: 1 })
      .expect(400);
    await request(http())
      .post('/orders')
      .set('Authorization', `Bearer ${clientToken}`)
      .set('Idempotency-Key', 'missing-address')
      .send({
        ...valid,
        delivery: {
          type: 'DELIVERY',
          recipientName: 'Cliente',
          phone: '900000000',
          zoneId,
        },
      })
      .expect(400);
    await request(http())
      .post('/orders')
      .set('Authorization', `Bearer ${adminToken}`)
      .set('Idempotency-Key', 'admin-checkout')
      .send(valid)
      .expect(403);
  });

  it('impide consultar o modificar pedidos y pagos de otro cliente', async () => {
    await request(http())
      .get(`/orders/${orderId}`)
      .set('Authorization', `Bearer ${otherToken}`)
      .expect(404);
    await request(http())
      .get(`/orders/${orderId}/payments`)
      .set('Authorization', `Bearer ${otherToken}`)
      .expect(404);
    await request(http())
      .post(`/orders/${orderId}/cancel`)
      .set('Authorization', `Bearer ${otherToken}`)
      .expect(404);
    await request(http())
      .post(`/orders/${orderId}/payments`)
      .set('Authorization', `Bearer ${otherToken}`)
      .send({ method: 'YAPE', reference: 'WRONG-OWNER-001' })
      .expect(404);
    const own = await request(http())
      .get('/orders')
      .set('Authorization', `Bearer ${clientToken}`)
      .expect(200);
    expect(
      own.body.items.every(
        (item: { userId: string }) => item.userId === clientUid,
      ),
    ).toBe(true);
    await request(http())
      .get('/admin/orders')
      .set('Authorization', `Bearer ${adminToken}`)
      .expect(200);
  });

  it('registra referencia, rechaza con motivo y acepta un nuevo intento sin ampliar el plazo', async () => {
    const before = (await firestore.collection('orders').doc(orderId).get())
      .data()!
      .reservationExpiresAt.toMillis();
    const submitted = await request(http())
      .post(`/orders/${orderId}/payments`)
      .set('Authorization', `Bearer ${clientToken}`)
      .send({ method: 'YAPE', reference: `FIRST-${orderId.slice(0, 12)}` })
      .expect(201);
    const firstId = submitted.body.id;
    await request(http())
      .post(`/admin/payments/${firstId}/approve`)
      .set('Authorization', `Bearer ${clientToken}`)
      .expect(403);
    await request(http())
      .post(`/admin/payments/${firstId}/reject`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ reason: 'Fondos no encontrados' })
      .expect(201);
    expect((await stock()).reserved).toBe(2);
    const second = await request(http())
      .post(`/orders/${orderId}/payments`)
      .set('Authorization', `Bearer ${clientToken}`)
      .send({ method: 'YAPE', reference: `SECOND-${orderId.slice(0, 12)}` })
      .expect(201);
    paymentId = second.body.id;
    const after = (await firestore.collection('orders').doc(orderId).get())
      .data()!
      .reservationExpiresAt.toMillis();
    expect(after).toBe(before);
    await request(http())
      .post(`/admin/payments/${firstId}/approve`)
      .set('Authorization', `Bearer ${adminToken}`)
      .expect(409);
    const attempts = await request(http())
      .get(`/orders/${orderId}/payments`)
      .set('Authorization', `Bearer ${clientToken}`)
      .expect(200);
    expect(attempts.body.items).toHaveLength(2);
  });

  it('aprueba de forma idempotente y avanza solo por estados logísticos válidos', async () => {
    const availableBefore = (await stock()).available;
    await request(http())
      .post(`/admin/payments/${paymentId}/approve`)
      .set('Authorization', `Bearer ${adminToken}`)
      .expect(201);
    await request(http())
      .post(`/admin/payments/${paymentId}/approve`)
      .set('Authorization', `Bearer ${adminToken}`)
      .expect(201);
    expect((await stock()).available).toBe(availableBefore);
    expect((await stock()).reserved).toBe(0);
    await request(http())
      .post(`/orders/${orderId}/cancel`)
      .set('Authorization', `Bearer ${clientToken}`)
      .expect(409);
    await request(http())
      .patch(`/admin/orders/${orderId}/status`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ status: 'ENTREGADO' })
      .expect(409);
    await request(http())
      .patch(`/admin/orders/${orderId}/status`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ status: 'EN_REPARTO' })
      .expect(200);
    await request(http())
      .patch(`/admin/orders/${orderId}/status`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ status: 'ENTREGADO' })
      .expect(200);
  });

  it('agrupa tallas duplicadas y cancela dos veces sin liberar stock dos veces', async () => {
    const before = (await stock()).available;
    const response = await checkout(
      'checkout-cancel-001',
      [
        { productId, size: '40', quantity: 1 },
        { productId, size: '40', quantity: 2 },
      ],
      true,
    ).expect(201);
    expect(response.body.items).toHaveLength(1);
    expect(response.body.items[0].quantity).toBe(3);
    expect(response.body.deliveryFeeCents).toBe(0);
    await request(http())
      .post(`/orders/${response.body.id}/cancel`)
      .set('Authorization', `Bearer ${clientToken}`)
      .expect(201);
    await request(http())
      .post(`/orders/${response.body.id}/cancel`)
      .set('Authorization', `Bearer ${clientToken}`)
      .expect(201);
    expect((await stock()).available).toBe(before);
    expect((await stock()).reserved).toBe(0);
  });

  it('evita sobreventa con dos checkouts simultáneos sobre la última unidad', async () => {
    await request(http())
      .post('/admin/inventory')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({
        productId,
        size: '41',
        quantity: 1,
        reason: 'Última unidad emulada',
      })
      .expect(201);
    const results = await Promise.all([
      checkout(
        'last-unit-checkout-A',
        [{ productId, size: '41', quantity: 1 }],
        true,
      ),
      checkout(
        'last-unit-checkout-B',
        [{ productId, size: '41', quantity: 1 }],
        true,
      ),
    ]);
    expect(
      results.map((result) => result.status).sort((a, b) => a - b),
    ).toEqual([201, 409]);
    expect((await stock('41')).available).toBe(0);
    expect((await stock('41')).reserved).toBe(1);
  });

  it('no duplica reservas con solicitudes simultáneas de la misma clave', async () => {
    const before = (await stock()).reserved;
    const responses = await Promise.all([
      checkout(
        'same-key-concurrent',
        [{ productId, size: '40', quantity: 1 }],
        true,
      ),
      checkout(
        'same-key-concurrent',
        [{ productId, size: '40', quantity: 1 }],
        true,
      ),
    ]);
    expect(responses.map((response) => response.status)).toEqual([201, 201]);
    expect(responses[0].body.id).toBe(responses[1].body.id);
    expect((await stock()).reserved).toBe(before + 1);
    await request(http())
      .post(`/orders/${responses[0].body.id}/cancel`)
      .set('Authorization', `Bearer ${clientToken}`)
      .expect(201);
  });

  it('vencimiento compite con aprobación y libera una sola vez', async () => {
    const before = (await stock()).available;
    const created = await checkout(
      'expiry-race-checkout',
      [{ productId, size: '40', quantity: 1 }],
      true,
    ).expect(201);
    const id = created.body.id;
    const payment = await request(http())
      .post(`/orders/${id}/payments`)
      .set('Authorization', `Bearer ${clientToken}`)
      .send({ method: 'YAPE', reference: `EXPIRE-${id.slice(0, 12)}` })
      .expect(201);
    const { Timestamp } = await import('firebase-admin/firestore');
    const past = Timestamp.fromMillis(Date.now() - 1000);
    // Solo se adelanta el reloj de este documento en el proyecto demo del emulador.
    await firestore
      .collection('orders')
      .doc(id)
      .update({ reservationExpiresAt: past, reservationDueAt: past });
    const results = await Promise.all([
      request(http())
        .post(`/admin/payments/${payment.body.id}/approve`)
        .set('Authorization', `Bearer ${adminToken}`),
      request(http())
        .post('/admin/orders/expire')
        .set('Authorization', `Bearer ${adminToken}`),
    ]);
    expect(results[0].status).toBe(409);
    expect(results[1].status).toBe(201);
    await request(http())
      .post('/admin/orders/expire')
      .set('Authorization', `Bearer ${adminToken}`)
      .expect(201);
    const order = await request(http())
      .get(`/orders/${id}`)
      .set('Authorization', `Bearer ${clientToken}`)
      .expect(200);
    expect(order.body.status).toBe('CANCELADO');
    expect(order.body.paymentStatus).toBe('VENCIDO');
    expect((await stock()).available).toBe(before);
    const release = await firestore
      .collection('inventory_movements')
      .where('orderId', '==', id)
      .where('type', '==', 'LIBERACION_RESERVA')
      .get();
    expect(release.size).toBe(1);
  });

  it('resuelve una carrera de cancelación contra aprobación con un solo cierre de reserva', async () => {
    const before = (await stock()).available;
    const created = await checkout(
      'cancel-approval-race',
      [{ productId, size: '40', quantity: 1 }],
      true,
    ).expect(201);
    const id = created.body.id;
    const payment = await request(http())
      .post(`/orders/${id}/payments`)
      .set('Authorization', `Bearer ${clientToken}`)
      .send({ method: 'YAPE', reference: `CANCEL-RACE-${id.slice(0, 12)}` })
      .expect(201);
    const responses = await Promise.all([
      request(http())
        .post(`/orders/${id}/cancel`)
        .set('Authorization', `Bearer ${clientToken}`),
      request(http())
        .post(`/admin/payments/${payment.body.id}/approve`)
        .set('Authorization', `Bearer ${adminToken}`),
    ]);
    expect(
      responses.map((response) => response.status).sort((a, b) => a - b),
    ).toEqual([201, 409]);
    const order = await request(http())
      .get(`/orders/${id}`)
      .set('Authorization', `Bearer ${clientToken}`)
      .expect(200);
    expect(['CANCELADO', 'PAGO_APROBADO']).toContain(order.body.status);
    expect((await stock()).available).toBe(
      order.body.status === 'CANCELADO' ? before : before - 1,
    );
    expect((await stock()).reserved).toBe(0);
    const movements = await firestore
      .collection('inventory_movements')
      .where('orderId', '==', id)
      .get();
    expect(
      movements.docs.filter((doc) =>
        ['LIBERACION_RESERVA', 'VENTA_PEDIDO'].includes(doc.data().type),
      ),
    ).toHaveLength(1);
  });

  it('rechaza referencias repetidas entre pedidos y nuevos intentos mientras hay uno en revisión', async () => {
    const first = await checkout(
      'duplicate-reference-a',
      [{ productId, size: '40', quantity: 1 }],
      true,
    ).expect(201);
    const second = await checkout(
      'duplicate-reference-b',
      [{ productId, size: '40', quantity: 1 }],
      true,
    ).expect(201);
    const reference = `DUPLICATE-${first.body.id.slice(0, 12)}`;
    const payment = await request(http())
      .post(`/orders/${first.body.id}/payments`)
      .set('Authorization', `Bearer ${clientToken}`)
      .send({ method: 'YAPE', reference })
      .expect(201);
    const retry = await request(http())
      .post(`/orders/${first.body.id}/payments`)
      .set('Authorization', `Bearer ${clientToken}`)
      .send({ method: 'YAPE', reference })
      .expect(201);
    expect(retry.body.id).toBe(payment.body.id);
    await request(http())
      .post(`/orders/${second.body.id}/payments`)
      .set('Authorization', `Bearer ${clientToken}`)
      .send({ method: 'YAPE', reference })
      .expect(409);
    await request(http())
      .post(`/orders/${first.body.id}/payments`)
      .set('Authorization', `Bearer ${clientToken}`)
      .send({ method: 'YAPE', reference: 'NEW-WHILE-PENDING' })
      .expect(409);
    await request(http())
      .post(`/orders/${first.body.id}/cancel`)
      .set('Authorization', `Bearer ${clientToken}`)
      .expect(201);
    await request(http())
      .post(`/orders/${second.body.id}/cancel`)
      .set('Authorization', `Bearer ${clientToken}`)
      .expect(201);
  });

  it('no permite checkout con zona o producto desactivados ni ajustes de inventario negativos', async () => {
    await request(http())
      .patch(`/admin/inventory/${productId}_40`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ delta: -1000, reason: 'Intento negativo' })
      .expect(409);
    await request(http())
      .delete(`/admin/delivery-zones/${zoneId}`)
      .set('Authorization', `Bearer ${adminToken}`)
      .expect(200);
    await checkout('inactive-zone-checkout').expect(409);
    await request(http())
      .patch(`/admin/delivery-zones/${zoneId}`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ active: true })
      .expect(200);
    await request(http())
      .delete(`/admin/products/${productId}`)
      .set('Authorization', `Bearer ${adminToken}`)
      .expect(200);
    await request(http()).get(`/products/${productId}`).expect(404);
    await checkout(
      'inactive-product-checkout',
      [{ productId, size: '40', quantity: 1 }],
      true,
    ).expect(409);
    await request(http())
      .patch(`/admin/products/${productId}`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ active: true })
      .expect(200);
    await request(http())
      .get('/admin/inventory/movements')
      .set('Authorization', `Bearer ${adminToken}`)
      .expect(200);
  });

  it('mantiene precios y tarifas históricos después de editar el catálogo', async () => {
    const created = await checkout('price-snapshot-checkout', [
      { productId, size: '40', quantity: 1 },
    ]).expect(201);
    await request(http())
      .patch(`/admin/products/${productId}`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ priceCents: 13000 })
      .expect(200);
    await request(http())
      .patch(`/admin/delivery-zones/${zoneId}`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ feeCents: 900 })
      .expect(200);
    const order = await request(http())
      .get(`/orders/${created.body.id}`)
      .set('Authorization', `Bearer ${clientToken}`)
      .expect(200);
    expect(order.body.totalCents).toBe(created.body.totalCents);
    expect(order.body.items[0].unitPriceCents).toBe(12000);
    await request(http())
      .post(`/orders/${created.body.id}/cancel`)
      .set('Authorization', `Bearer ${clientToken}`)
      .expect(201);
  });

  it('protege delivery, ajustes, pagos y vencimientos ante un cliente sin permisos', async () => {
    for (const path of [
      '/admin/delivery-zones',
      '/admin/store-settings',
      '/admin/orders',
    ]) {
      await request(http())
        .get(path)
        .set('Authorization', `Bearer ${clientToken}`)
        .expect(403);
    }
    await request(http())
      .post('/admin/orders/expire')
      .set('Authorization', `Bearer ${clientToken}`)
      .expect(403);
  });
});
