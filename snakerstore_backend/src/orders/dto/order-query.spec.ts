import { dateBounds, OrderQueryDto } from './order-query.dto.js';
import { OrdersRepository } from '../orders.repository.js';
import { Timestamp, type Firestore } from 'firebase-admin/firestore';

describe('Fechas de pedidos en Perú', () => {
  it('incluye todo el último día en Lima', () => {
    const bounds = dateBounds({ from: '2026-10-01', to: '2026-10-01' });
    expect(new Date(bounds.from!).toISOString()).toBe(
      '2026-10-01T05:00:00.000Z',
    );
    expect(new Date(bounds.to!).toISOString()).toBe('2026-10-02T05:00:00.000Z');
  });
  it('rechaza fechas inexistentes y rangos invertidos', () => {
    expect(() => dateBounds({ from: '2026-02-30' })).toThrow('inválida');
    expect(() => dateBounds({ from: '2026-10-02', to: '2026-10-01' })).toThrow(
      'posterior',
    );
    expect(() => dateBounds({ to: '27/10/2026' })).toThrow('inválida');
  });
  it('aplica fechas antes de paginar, con orden estable y cursor de documento', async () => {
    const query = {
      where: vi.fn().mockReturnThis(),
      orderBy: vi.fn().mockReturnThis(),
      startAfter: vi.fn().mockReturnThis(),
      limit: vi.fn().mockReturnThis(),
      get: vi.fn().mockResolvedValue({
        size: 3,
        docs: [
          { id: 'a', data: () => ({}) },
          { id: 'b', data: () => ({}) },
          { id: 'c', data: () => ({}) },
        ],
      }),
      doc: vi.fn(() => ({
        get: async () => ({ exists: true, id: 'previous' }),
      })),
    };
    const db = { collection: () => query } as unknown as Firestore;
    const repository = new OrdersRepository(db);
    const result = await repository.list(
      Object.assign(new OrderQueryDto(), {
        from: '2026-10-01',
        to: '2026-10-27',
        after: 'previous',
        limit: 2,
      }),
    );
    expect(query.where).toHaveBeenCalledWith(
      'createdAt',
      '>=',
      expect.any(Timestamp),
    );
    expect(query.where).toHaveBeenCalledWith(
      'createdAt',
      '<',
      expect.any(Timestamp),
    );
    expect(query.startAfter).toHaveBeenCalledWith(
      expect.objectContaining({ id: 'previous' }),
    );
    expect(result.nextCursor).toBe('b');
    expect(result.items).toHaveLength(2);
  });
});
