import type { Firestore } from 'firebase-admin/firestore';
import type { DecodedIdToken } from 'firebase-admin/auth';
import { UsersRepository } from './users.repository.js';

describe('UsersRepository', () => {
  const identity = {
    uid: 'trusted-uid',
    email: 'test@example.invalid',
    name: 'Nombre',
    role: 'ADMINISTRADOR',
  } as unknown as DecodedIdToken;
  const ref = {};
  const doc = vi.fn(() => ref);
  const collection = vi.fn(() => ({ doc }));
  const get = vi.fn();
  const create = vi.fn();
  const runTransaction = vi.fn(async (callback) => callback({ get, create }));
  const repository = new UsersRepository({
    collection,
    runTransaction,
  } as unknown as Firestore);

  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('crea perfiles nuevos como CLIENTE ignorando roles del token', async () => {
    get.mockResolvedValue({ exists: false });
    expect(await repository.findOrCreate(identity)).toEqual({
      email: identity.email,
      name: 'Nombre',
      role: 'CLIENTE',
    });
    expect(collection).toHaveBeenCalledWith('users');
    expect(doc).toHaveBeenCalledWith('trusted-uid');
    expect(create).toHaveBeenCalledWith(
      ref,
      expect.objectContaining({
        role: 'CLIENTE',
        createdAt: expect.anything(),
      }),
    );
  });
  it('conserva el perfil administrador existente sin escrituras', async () => {
    const existing = { role: 'ADMINISTRADOR', name: 'Original' };
    get.mockResolvedValue({ exists: true, data: () => existing });
    expect(await repository.findOrCreate(identity)).toBe(existing);
    expect(create).not.toHaveBeenCalled();
  });
  it('no intenta recrear perfiles cuando falla la lectura', async () => {
    get.mockRejectedValue(new Error('unavailable'));
    await expect(repository.findOrCreate(identity)).rejects.toThrow(
      'unavailable',
    );
    expect(create).not.toHaveBeenCalled();
  });
});
