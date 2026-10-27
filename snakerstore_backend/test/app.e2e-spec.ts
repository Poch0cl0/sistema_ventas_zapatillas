import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { App } from 'supertest/types.js';
import { AppModule } from './../src/app.module.js';
import { DefaultProductsService } from '../src/products/default-products.js';
import {
  FIREBASE_APP,
  FIREBASE_AUTH,
  FIREBASE_FIRESTORE,
} from './../src/firebase/firebase.providers.js';

vi.hoisted(() => {
  process.env.FIREBASE_PROJECT_ID = 'snakerstore-e74cd';
  process.env.FIREBASE_SERVICE_ACCOUNT = './fake-service-account.json';
  process.env.PORT = '3000';
});

describe('AppController (e2e)', () => {
  let app: INestApplication<App>;

  beforeEach(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    })
      .overrideProvider(FIREBASE_APP)
      .useValue({})
      .overrideProvider(FIREBASE_AUTH)
      .useValue({})
      .overrideProvider(FIREBASE_FIRESTORE)
      .useValue({})
      .overrideProvider(DefaultProductsService)
      .useValue({ onModuleInit: async () => {} })
      .compile();

    app = moduleFixture.createNestApplication();
    await app.init();
  });

  it('/ (GET)', () => {
    return request(app.getHttpServer())
      .get('/')
      .expect(200)
      .expect('Hello World!');
  });

  afterEach(async () => {
    await app.close();
  });
});
