import { Controller, Get } from '@nestjs/common';
import type { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../src/app.module.js';
import { Roles } from '../src/common/decorators/auth.decorators.js';
import {
  FIREBASE_APP,
  FIREBASE_AUTH,
  FIREBASE_FIRESTORE,
} from '../src/firebase/firebase.providers.js';
import { UsersRepository } from '../src/users/users.repository.js';

vi.hoisted(() => {
  process.env.FIREBASE_PROJECT_ID = 'snakerstore-e74cd';
  process.env.FIREBASE_SERVICE_ACCOUNT = './fake-service-account.json';
  process.env.PORT = '3000';
});

// Ruta exclusiva de pruebas: comprueba la protección de futuros controladores admin.
@Controller('test-admin')
class AdminTestController {
  @Get()
  @Roles('ADMINISTRADOR')
  get() {
    return { allowed: true };
  }
}

describe('Autenticación y roles (HTTP, Firebase simulado)', () => {
  let app: INestApplication;
  const verifyIdToken = vi.fn();
  const findOrCreate = vi.fn();

  beforeAll(async () => {
    const module = await Test.createTestingModule({
      imports: [AppModule],
      controllers: [AdminTestController],
    })
      .overrideProvider(FIREBASE_APP)
      .useValue({})
      .overrideProvider(FIREBASE_AUTH)
      .useValue({ verifyIdToken })
      .overrideProvider(FIREBASE_FIRESTORE)
      .useValue({})
      .overrideProvider(UsersRepository)
      .useValue({ findOrCreate })
      .compile();
    app = module.createNestApplication();
    await app.init();
  });
  afterAll(async () => {
    await app.close();
  });
  beforeEach(() => {
    vi.resetAllMocks();
    verifyIdToken.mockResolvedValue({
      uid: 'trusted-uid',
      email: 'test@example.invalid',
      role: 'ADMINISTRADOR',
    });
    findOrCreate.mockResolvedValue({
      name: 'Cliente',
      role: 'CLIENTE',
      privateField: 'hidden',
    });
  });

  it('mantiene pública la raíz sin consultar Firebase', async () => {
    await request(app.getHttpServer()).get('/').expect(200);
    expect(verifyIdToken).not.toHaveBeenCalled();
  });
  it.each([undefined, 'Basic abc', 'Bearer', 'Bearer one two'])(
    'rechaza un encabezado inválido: %s',
    async (header) => {
      const req = request(app.getHttpServer()).get('/auth/me');
      if (header) req.set('Authorization', header);
      await req.expect(401);
      expect(findOrCreate).not.toHaveBeenCalled();
    },
  );
  it.each([
    'auth/id-token-expired',
    'auth/id-token-revoked',
    'auth/user-disabled',
    'auth/argument-error',
  ])('rechaza la sesión %s', async (code) => {
    verifyIdToken.mockRejectedValue({ code });
    await request(app.getHttpServer())
      .get('/auth/me')
      .set('Authorization', 'Bearer fake')
      .expect(401);
    expect(findOrCreate).not.toHaveBeenCalled();
  });
  it('devuelve únicamente el perfil seguro y el rol de Firestore', async () => {
    const response = await request(app.getHttpServer())
      .get('/auth/me?role=ADMINISTRADOR&uid=other')
      .set('Authorization', 'Bearer fake')
      .expect(200);
    expect(response.body).toEqual({
      uid: 'trusted-uid',
      email: 'test@example.invalid',
      name: 'Cliente',
      role: 'CLIENTE',
    });
    expect(response.headers['cache-control']).toBe('no-store');
    expect(verifyIdToken).toHaveBeenCalledWith('fake', true);
  });
  it('deniega acceso admin a un cliente aunque su token diga ADMINISTRADOR', async () => {
    await request(app.getHttpServer())
      .get('/test-admin')
      .set('Authorization', 'Bearer fake')
      .expect(403);
  });
  it('permite acceso al administrador confirmado por Firestore', async () => {
    findOrCreate.mockResolvedValue({ role: 'ADMINISTRADOR', name: 'Admin' });
    await request(app.getHttpServer())
      .get('/test-admin')
      .set('Authorization', 'Bearer fake')
      .expect(200);
  });
  it('rechaza roles ausentes o desconocidos', async () => {
    findOrCreate.mockResolvedValue({ role: 'SUPERADMIN' });
    await request(app.getHttpServer())
      .get('/auth/me')
      .set('Authorization', 'Bearer fake')
      .expect(403);
  });
  it('informa indisponibilidad sin exponer detalles de Firestore', async () => {
    findOrCreate.mockRejectedValue(new Error('private details'));
    const response = await request(app.getHttpServer())
      .get('/auth/me')
      .set('Authorization', 'Bearer fake')
      .expect(503);
    expect(JSON.stringify(response.body)).not.toContain('private details');
  });
  it('distingue un fallo de Firebase de una sesión inválida', async () => {
    verifyIdToken.mockRejectedValue({ code: 'auth/internal-error' });
    await request(app.getHttpServer())
      .get('/auth/me')
      .set('Authorization', 'Bearer fake')
      .expect(503);
  });
});
