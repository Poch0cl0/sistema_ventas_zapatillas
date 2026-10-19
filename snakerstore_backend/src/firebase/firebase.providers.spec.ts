import { ConfigService } from '@nestjs/config';
import { readFileSync } from 'node:fs';
import { cert, getApps, initializeApp } from 'firebase-admin/app';
import type { App } from 'firebase-admin/app';
import { createFirebaseApp } from './firebase.providers.js';
import { FIREBASE_PROJECT_ID } from '../config/environment.js';

vi.mock('node:fs', () => ({ readFileSync: vi.fn() }));
vi.mock('firebase-admin/app', () => ({
  cert: vi.fn(),
  getApps: vi.fn(),
  initializeApp: vi.fn(),
}));

describe('createFirebaseApp', () => {
  const config = new ConfigService({
    FIREBASE_PROJECT_ID,
    FIREBASE_SERVICE_ACCOUNT: './fake.json',
  });
  const app = {
    name: '[DEFAULT]',
    options: { projectId: FIREBASE_PROJECT_ID },
  } as App;

  beforeEach(() => {
    vi.resetAllMocks();
    vi.mocked(getApps).mockReturnValue([]);
    vi.mocked(initializeApp).mockReturnValue(app);
    vi.mocked(readFileSync).mockReturnValue(
      JSON.stringify({
        project_id: FIREBASE_PROJECT_ID,
        client_email: 'test@example.invalid',
        private_key: 'FAKE-SECRET',
      }),
    );
  });

  it('inicializa una vez y reutiliza la aplicación del proyecto correcto', () => {
    expect(createFirebaseApp(config)).toBe(app);
    vi.mocked(getApps).mockReturnValue([app]);
    expect(createFirebaseApp(config)).toBe(app);
    expect(initializeApp).toHaveBeenCalledTimes(1);
    expect(cert).toHaveBeenCalledTimes(1);
    expect(readFileSync).toHaveBeenCalledTimes(1);
  });

  it('rechaza una aplicación existente de otro proyecto', () => {
    vi.mocked(getApps).mockReturnValue([
      { ...app, options: { projectId: 'otro' } } as App,
    ]);
    expect(() => createFirebaseApp(config)).toThrow('otro proyecto');
    expect(initializeApp).not.toHaveBeenCalled();
  });

  it('rechaza una cuenta de servicio de otro proyecto', () => {
    vi.mocked(readFileSync).mockReturnValue(
      JSON.stringify({ project_id: 'otro' }),
    );
    expect(() => createFirebaseApp(config)).toThrow('otro proyecto');
    expect(initializeApp).not.toHaveBeenCalled();
  });

  it.each(['missing', 'json', 'key'])(
    'oculta detalles sensibles en errores de tipo %s',
    (kind) => {
      if (kind === 'missing')
        vi.mocked(readFileSync).mockImplementation(() => {
          throw new Error('FAKE-SECRET');
        });
      if (kind === 'json')
        vi.mocked(readFileSync).mockReturnValue('FAKE-SECRET');
      if (kind === 'key')
        vi.mocked(cert).mockImplementation(() => {
          throw new Error('FAKE-SECRET');
        });
      expect(() => createFirebaseApp(config)).toThrow();
      expect(() => createFirebaseApp(config)).not.toThrow('FAKE-SECRET');
    },
  );
});
