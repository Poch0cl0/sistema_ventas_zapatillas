import { validate } from 'class-validator';
import { plainToInstance } from 'class-transformer';
import { UpdateProductDto } from './product.dto.js';
import { ProductsRepository } from '../products.repository.js';
import type { Firestore } from 'firebase-admin/firestore';

describe('Género y colores del catálogo', () => {
  it('rellena la página pública sin revelar artículos inactivos ni saltar el cursor', async () => {
    const docs = [
      { id: 'inactive', data: () => ({ active: false }) },
      ...['p1', 'p2', 'p3'].map((id) => ({
        id,
        data: () => ({ active: true, gender: 'MUJER' }),
      })),
    ];
    const query = {
      where: vi.fn().mockReturnThis(),
      orderBy: vi.fn().mockReturnThis(),
      limit: vi.fn().mockReturnThis(),
      get: async () => ({ docs }),
    };
    const repository = new ProductsRepository({
      collection: () => query,
    } as unknown as Firestore);
    const result = await repository.list({ gender: 'MUJER', limit: 2 }, true);
    expect(result.items.map((p) => p.id)).toEqual(['p1', 'p2']);
    expect(result.nextCursor).toBe('p2');
  });
  it('admite varios colores y conserva compatibilidad con productos antiguos', async () => {
    expect(
      await validate(
        plainToInstance(UpdateProductDto, {
          gender: 'MUJER',
          colors: ['ROJO', 'BLANCO'],
        }),
      ),
    ).toHaveLength(0);
    expect(
      await validate(plainToInstance(UpdateProductDto, { name: 'Anterior' })),
    ).toHaveLength(0);
  });
  it.each([
    { gender: 'OTRO' },
    { gender: null },
    { colors: null },
    { colors: ['ROJO', 'ROJO'] },
    { colors: ['INVALIDO'] },
    { colors: 'AZUL' },
  ])('rechaza atributos inválidos %j', async (input) => {
    expect(
      (await validate(plainToInstance(UpdateProductDto, input))).length,
    ).toBeGreaterThan(0);
  });
  it('filtra en Firestore antes de aplicar el límite y el cursor', async () => {
    const query = {
      where: vi.fn().mockReturnThis(),
      orderBy: vi.fn().mockReturnThis(),
      startAfter: vi.fn().mockReturnThis(),
      limit: vi.fn().mockReturnThis(),
      get: async () => ({ docs: [] }),
    };
    const repository = new ProductsRepository({
      collection: () => query,
    } as unknown as Firestore);
    await repository.list(
      { gender: 'HOMBRE', limit: 20, after: 'previous' },
      true,
    );
    expect(query.where).toHaveBeenCalledWith('gender', '==', 'HOMBRE');
    expect(query.startAfter).toHaveBeenCalledWith('previous');
    expect(query.limit).toHaveBeenCalledWith(100);
  });
});
