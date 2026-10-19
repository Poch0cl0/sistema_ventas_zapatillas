import type { Firestore } from 'firebase-admin/firestore';
import { ProductsRepository } from './products.repository.js';
import { publicProduct } from '../common/firestore-page.js';

describe('Productos: visibilidad y edición', () => {
  const get = vi.fn();
  const update = vi.fn();
  const reference = { get };
  const runTransaction = vi.fn(async (callback) => callback({ get, update }));
  const firestore = {
    collection: () => ({ doc: () => reference }),
    runTransaction,
  } as unknown as Firestore;
  const repository = new ProductsRepository(firestore);
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('no revela productos inactivos a consultas públicas', async () => {
    get.mockResolvedValue({
      exists: true,
      id: 'product1',
      data: () => ({ active: false }),
    });
    await expect(repository.find('product1', true)).rejects.toThrow(
      'no encontrado',
    );
    await expect(repository.find('product1', false)).resolves.toMatchObject({
      id: 'product1',
      active: false,
    });
  });
  it('devuelve 404 si falta el producto', async () => {
    get.mockResolvedValue({ exists: false });
    await expect(repository.find('missing', true)).rejects.toThrow(
      'no encontrado',
    );
  });
  it('conserva el resto de campos al editar y audita al actor', async () => {
    get.mockResolvedValue({
      exists: true,
      data: () => ({ name: 'Original', active: true, priceCents: 1000 }),
    });
    const result = await repository.update(
      'product1',
      { priceCents: 2000 },
      'actor',
    );
    expect(result).toMatchObject({ name: 'Original', priceCents: 2000 });
    expect(update).toHaveBeenCalledWith(
      reference,
      expect.objectContaining({ priceCents: 2000, updatedBy: 'actor' }),
    );
  });
  it('expone solo datos públicos e imágenes sin identificadores internos', () => {
    const result = publicProduct('product1', {
      name: 'Público',
      secret: 'hidden',
      createdBy: 'actor',
      images: [
        {
          secure_url: 'https://example.invalid/photo.jpg',
          public_id: 'internal',
        },
      ],
    });
    expect(result).not.toHaveProperty('secret');
    expect(result).not.toHaveProperty('createdBy');
    expect(result.images).toEqual([
      { secure_url: 'https://example.invalid/photo.jpg' },
    ]);
  });
});
