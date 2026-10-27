import type { Firestore } from 'firebase-admin/firestore';
import { DEFAULT_PRODUCTS, ensureDefaultProducts } from './default-products.js';

describe('Artículos incluidos para el probador', () => {
  function database(existing: boolean[]) {
    const create = vi.fn();
    const refs = DEFAULT_PRODUCTS.map((p) => ({ id: p.id }));
    const firestore = {
      collection: vi.fn(() => ({
        doc: (id: string) => refs.find((r) => r.id === id),
      })),
      runTransaction: async (callback: (t: unknown) => unknown) =>
        callback({
          getAll: async () => existing.map((exists) => ({ exists })),
          create,
        }),
    } as unknown as Firestore;
    return { firestore, create };
  }
  it('crea ambos artículos con modelos incluidos y sin inventar existencias', async () => {
    const { firestore, create } = database([false, false]);
    await ensureDefaultProducts(firestore);
    expect(create).toHaveBeenCalledTimes(2);
    expect(create.mock.calls.map(([, data]) => data)).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          bundledModel: 'urban_sand',
          active: true,
          tryOnEnabled: true,
        }),
        expect.objectContaining({
          bundledModel: 'sport_night',
          active: true,
          tryOnEnabled: true,
        }),
      ]),
    );
    expect(firestore.collection).toHaveBeenCalledTimes(2);
    expect(firestore.collection).toHaveBeenCalledWith('products');
  });
  it('no sobrescribe los artículos existentes aunque estén desactivados o editados', async () => {
    const { firestore, create } = database([true, true]);
    await ensureDefaultProducts(firestore);
    expect(create).not.toHaveBeenCalled();
  });
  it('crea únicamente el artículo que falta', async () => {
    const { firestore, create } = database([true, false]);
    await ensureDefaultProducts(firestore);
    expect(create).toHaveBeenCalledTimes(1);
    expect(create.mock.calls[0][0].id).toBe('demo-urban-sand');
  });
});
