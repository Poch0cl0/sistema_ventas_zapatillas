import type { Firestore } from 'firebase-admin/firestore';
import {
  adjustedAvailable,
  InventoryRepository,
} from './inventory.repository.js';

describe('Reglas de stock disponible', () => {
  it('suma o resta únicamente unidades disponibles', () => {
    expect(adjustedAvailable(10, 3, -2)).toBe(8);
    expect(adjustedAvailable(10, 3, -10)).toBe(0);
  });
  it.each([
    [1, 2, -2],
    [1000000, 0, 1],
    [-1, 0, 1],
    [1, -1, 1],
    [1.5, 0, 1],
    [1, '2', 1],
  ])('rechaza stock insuficiente o corrupto', (available, reserved, delta) => {
    expect(() =>
      adjustedAvailable(available, reserved, Number(delta)),
    ).toThrow();
  });
});

describe('Persistencia transaccional de inventario', () => {
  const get = vi.fn();
  const getAll = vi.fn();
  const create = vi.fn();
  const update = vi.fn();
  const refs = new Map<string, { path: string }>();
  const collection = vi.fn((name: string) => ({
    doc: (id = 'movement-id') => {
      const path = `${name}/${id}`;
      if (!refs.has(path)) refs.set(path, { path });
      return refs.get(path);
    },
  }));
  const runTransaction = vi.fn(async (callback) =>
    callback({ get, getAll, create, update }),
  );
  const repository = new InventoryRepository({
    collection,
    runTransaction,
  } as unknown as Firestore);
  const initial = {
    productId: 'product1',
    size: '40',
    quantity: 10,
    reason: 'Ingreso inicial',
  };

  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('crea inventario y auditoría en la misma transacción, leyendo antes de escribir', async () => {
    getAll.mockResolvedValue([{ exists: true }, { exists: false }]);
    const result = await repository.create(initial, 'actor');
    expect(result).toEqual({
      id: 'product1_40',
      productId: 'product1',
      size: '40',
      available: 10,
      reserved: 0,
    });
    expect(runTransaction).toHaveBeenCalledTimes(1);
    expect(create).toHaveBeenCalledTimes(2);
    expect(create).toHaveBeenCalledWith(
      expect.objectContaining({ path: 'inventory_movements/movement-id' }),
      expect.objectContaining({
        actorId: 'actor',
        type: 'INGRESO_INICIAL',
        delta: 10,
      }),
    );
    expect(getAll.mock.invocationCallOrder[0]).toBeLessThan(
      create.mock.invocationCallOrder[0],
    );
  });
  it.each([
    [false, false],
    [true, true],
  ])(
    'no escribe ante producto inexistente o talla duplicada',
    async (productExists, inventoryExists) => {
      getAll.mockResolvedValue([
        { exists: productExists },
        { exists: inventoryExists },
      ]);
      await expect(repository.create(initial, 'actor')).rejects.toThrow();
      expect(create).not.toHaveBeenCalled();
    },
  );
  it('ajusta stock sin tocar reserved y audita el cambio', async () => {
    get.mockResolvedValue({
      exists: true,
      data: () => ({
        productId: 'product1',
        size: '40',
        available: 5,
        reserved: 3,
      }),
    });
    const result = await repository.adjust(
      'product1_40',
      { delta: -2, reason: 'Corrección' },
      'actor',
    );
    expect(result.available).toBe(3);
    expect(result.reserved).toBe(3);
    expect(update).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({ available: 3 }),
    );
    expect(update.mock.calls[0][1]).not.toHaveProperty('reserved');
    expect(create).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({
        availableBefore: 5,
        availableAfter: 3,
        actorId: 'actor',
        delta: -2,
      }),
    );
  });
  it('no genera movimiento ni actualiza ante stock insuficiente', async () => {
    get.mockResolvedValue({
      exists: true,
      data: () => ({ available: 1, reserved: 10 }),
    });
    await expect(
      repository.adjust(
        'product1_40',
        { delta: -2, reason: 'Corrección' },
        'actor',
      ),
    ).rejects.toThrow();
    expect(update).not.toHaveBeenCalled();
    expect(create).not.toHaveBeenCalled();
  });
  it('devuelve error cuando la talla no existe', async () => {
    get.mockResolvedValue({ exists: false });
    await expect(
      repository.adjust(
        'product1_40',
        { delta: 2, reason: 'Reposición' },
        'actor',
      ),
    ).rejects.toThrow('no encontrado');
    expect(create).not.toHaveBeenCalled();
  });
});
