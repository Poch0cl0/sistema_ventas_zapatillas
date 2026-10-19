import { firestorePage } from './firestore-page.js';
import type { Query } from 'firebase-admin/firestore';

describe('Paginación Firestore', () => {
  it('limita lecturas, aplica cursor y devuelve un cursor solo si hay más resultados', async () => {
    const get = vi
      .fn()
      .mockResolvedValue({ docs: [{ id: 'a' }, { id: 'b' }, { id: 'c' }] });
    const query = {
      orderBy: vi.fn().mockReturnThis(),
      startAfter: vi.fn().mockReturnThis(),
      limit: vi.fn().mockReturnThis(),
      get,
    };
    const page = await firestorePage(query as unknown as Query, {
      limit: 2,
      after: 'previous',
    });
    expect(query.startAfter).toHaveBeenCalledWith('previous');
    expect(query.limit).toHaveBeenCalledWith(3);
    expect(page.nextCursor).toBe('b');
    expect(page.docs).toHaveLength(2);
    get.mockResolvedValueOnce({ docs: [{ id: 'c' }] });
    expect(
      (await firestorePage(query as unknown as Query, { limit: 2 })).nextCursor,
    ).toBeNull();
  });
});
