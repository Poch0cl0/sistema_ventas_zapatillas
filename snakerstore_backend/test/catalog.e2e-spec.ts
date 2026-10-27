import { Test } from '@nestjs/testing';
import { DemoGatewayService } from '../src/payments/demo-gateway.js';
import { OrdersRepository } from '../src/orders/orders.repository.js';
import { DefaultProductsService } from '../src/products/default-products.js';
import type { INestApplication } from '@nestjs/common';
import {
  BadRequestException,
  ConflictException,
  NotFoundException,
} from '@nestjs/common';
import request from 'supertest';
import { AppModule } from '../src/app.module.js';
import { configureSwagger } from '../src/config/swagger.js';
import {
  FIREBASE_APP,
  FIREBASE_AUTH,
  FIREBASE_FIRESTORE,
} from '../src/firebase/firebase.providers.js';
import { UsersRepository } from '../src/users/users.repository.js';
import { ProductsRepository } from '../src/products/products.repository.js';
import { InventoryRepository } from '../src/inventory/inventory.repository.js';

vi.hoisted(() => {
  process.env.FIREBASE_PROJECT_ID = 'snakerstore-e74cd';
  process.env.FIREBASE_SERVICE_ACCOUNT = './fake-service-account.json';
  process.env.PORT = '3000';
});

describe('Catálogo, inventario, validación y Swagger (HTTP)', () => {
  let app: INestApplication;
  const product = {
    name: 'Urbana',
    description: 'Zapatilla de uso diario',
    priceCents: 25990,
    brand: 'Marca',
    category: 'Urbano',
    active: true,
  };
  const products = {
    list: vi.fn(),
    find: vi.fn(),
    create: vi.fn(),
    update: vi.fn(),
  };
  const demoGateway = { checkout: vi.fn(), find: vi.fn(), confirm: vi.fn() };
  const orders = { list: vi.fn() };
  const inventory = {
    list: vi.fn(),
    create: vi.fn(),
    adjust: vi.fn(),
    movements: vi.fn(),
  };
  const verifyIdToken = vi.fn(async (token: string) => ({
    uid: token,
    email: 'test@example.invalid',
  }));

  beforeAll(async () => {
    const module = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(FIREBASE_APP)
      .useValue({})
      .overrideProvider(FIREBASE_AUTH)
      .useValue({ verifyIdToken })
      .overrideProvider(FIREBASE_FIRESTORE)
      .useValue({})
      .overrideProvider(DefaultProductsService)
      .useValue({ onModuleInit: async () => {} })
      .overrideProvider(UsersRepository)
      .useValue({
        findOrCreate: async (identity: { uid: string }) => ({
          role: identity.uid === 'admin' ? 'ADMINISTRADOR' : 'CLIENTE',
          name: 'Prueba',
        }),
      })
      .overrideProvider(ProductsRepository)
      .useValue(products)
      .overrideProvider(DemoGatewayService)
      .useValue(demoGateway)
      .overrideProvider(OrdersRepository)
      .useValue(orders)
      .overrideProvider(InventoryRepository)
      .useValue(inventory)
      .compile();
    app = module.createNestApplication();
    configureSwagger(app);
    await app.init();
  });
  afterAll(async () => {
    await app.close();
  });
  beforeEach(() => {
    vi.clearAllMocks();
    products.list.mockResolvedValue({ items: [], nextCursor: null });
    products.create.mockResolvedValue({
      id: 'product1',
      ...product,
      images: [],
    });
    products.find.mockResolvedValue({ id: 'product1', ...product, images: [] });
    products.update.mockResolvedValue({ id: 'product1', ...product });
    inventory.create.mockResolvedValue({
      id: 'product1_40',
      productId: 'product1',
      size: '40',
      available: 10,
      reserved: 0,
    });
    inventory.adjust.mockResolvedValue({
      id: 'product1_40',
      available: 15,
      reserved: 2,
    });
  });

  it('expone Swagger y contratos con bearer y parámetros', async () => {
    await request(app.getHttpServer()).get('/docs/').expect(200);
    const response = await request(app.getHttpServer())
      .get('/docs-json')
      .expect(200);
    const paths = response.body.paths;
    expect(paths['/admin/products'].post.security).toEqual([{ bearer: [] }]);
    expect(paths['/products'].get.security ?? []).toEqual([]);
    expect(paths['/admin/inventory/{id}'].patch.parameters).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ name: 'id', in: 'path' }),
      ]),
    );
    expect(paths['/admin/products'].post.requestBody).toBeDefined();
  });
  it('lista catálogo público con paginación convertida y filtro activo', async () => {
    await request(app.getHttpServer())
      .get('/products?limit=2&after=abc')
      .expect(200);
    expect(products.list).toHaveBeenCalledWith(
      expect.objectContaining({ limit: 2, after: 'abc' }),
      true,
    );
    expect(verifyIdToken).not.toHaveBeenCalled();
  });
  it.each([
    '/admin/products',
    '/admin/inventory',
    '/admin/inventory/movements',
  ])('protege %s', async (path) => {
    await request(app.getHttpServer()).get(path).expect(401);
    await request(app.getHttpServer())
      .get(path)
      .set('Authorization', 'Bearer client')
      .expect(403);
  });
  it('crea un producto y toma al actor del token', async () => {
    await request(app.getHttpServer())
      .post('/admin/products')
      .set('Authorization', 'Bearer admin')
      .send(product)
      .expect(201);
    expect(products.create).toHaveBeenCalledWith(
      expect.objectContaining(product),
      'admin',
    );
  });
  it.each([
    { ...product, priceCents: -1 },
    { ...product, priceCents: 25.5 },
    { ...product, priceCents: '25990' },
    { ...product, active: 'false' },
    { ...product, role: 'ADMINISTRADOR' },
    { ...product, images: ['http://invalid'] },
    { ...product, name: '   ' },
    { ...product, priceCents: null },
  ])('rechaza productos inválidos o campos externos', async (body) => {
    await request(app.getHttpServer())
      .post('/admin/products')
      .set('Authorization', 'Bearer admin')
      .send(body)
      .expect(400);
    expect(products.create).not.toHaveBeenCalled();
  });
  it.each([{}, { name: null }, { priceCents: null }, { createdBy: 'other' }])(
    'rechaza una edición inválida',
    async (body) => {
      await request(app.getHttpServer())
        .patch('/admin/products/product1')
        .set('Authorization', 'Bearer admin')
        .send(body)
        .expect(400);
      expect(products.update).not.toHaveBeenCalled();
    },
  );
  it('desactiva el producto mediante borrado lógico', async () => {
    await request(app.getHttpServer())
      .delete('/admin/products/product1')
      .set('Authorization', 'Bearer admin')
      .expect(200);
    expect(products.update).toHaveBeenCalledWith(
      'product1',
      { active: false },
      'admin',
    );
  });
  it.each([
    'limit=0',
    'limit=101',
    'limit=abc',
    'unknown=true',
    'after=bad%2Fid',
  ])('rechaza paginación inválida: %s', async (query) => {
    await request(app.getHttpServer()).get(`/products?${query}`).expect(400);
  });
  it('crea una talla con stock inicial', async () => {
    const body = {
      productId: 'product1',
      size: '40',
      quantity: 10,
      reason: 'Ingreso inicial',
    };
    await request(app.getHttpServer())
      .post('/admin/inventory')
      .set('Authorization', 'Bearer admin')
      .send(body)
      .expect(201);
    expect(inventory.create).toHaveBeenCalledWith(
      expect.objectContaining(body),
      'admin',
    );
  });
  it.each([
    { size: 40 },
    { size: '040' },
    { quantity: -1 },
    { reserved: 100 },
    { reason: ' ' },
    { productId: '../bad' },
  ])('rechaza inventario inválido', async (changes) => {
    await request(app.getHttpServer())
      .post('/admin/inventory')
      .set('Authorization', 'Bearer admin')
      .send({
        productId: 'product1',
        size: '40',
        quantity: 10,
        reason: 'Ingreso inicial',
        ...changes,
      })
      .expect(400);
    expect(inventory.create).not.toHaveBeenCalled();
  });
  it('ajusta cantidades y entrega al repositorio la identidad verificada', async () => {
    await request(app.getHttpServer())
      .patch('/admin/inventory/product1_40')
      .set('Authorization', 'Bearer admin')
      .send({ delta: -2, reason: 'Corrección de conteo' })
      .expect(200);
    expect(inventory.adjust).toHaveBeenCalledWith(
      'product1_40',
      expect.objectContaining({ delta: -2 }),
      'admin',
    );
  });
  it.each([
    { delta: 0 },
    { delta: 1.5 },
    { delta: '2' },
    { available: 2 },
    { reserved: 2 },
  ])('rechaza ajustes inválidos', async (changes) => {
    await request(app.getHttpServer())
      .patch('/admin/inventory/product1_40')
      .set('Authorization', 'Bearer admin')
      .send({ delta: 2, reason: 'Corrección de conteo', ...changes })
      .expect(400);
    expect(inventory.adjust).not.toHaveBeenCalled();
  });
  it.each([
    new NotFoundException('No encontrado'),
    new ConflictException('Stock insuficiente'),
    new BadRequestException('Inválido'),
  ])('mantiene errores de dominio', async (error) => {
    inventory.adjust.mockRejectedValueOnce(error);
    await request(app.getHttpServer())
      .patch('/admin/inventory/product1_40')
      .set('Authorization', 'Bearer admin')
      .send({ delta: -2, reason: 'Corrección' })
      .expect(error.getStatus());
  });
  it('oculta detalles internos de errores de persistencia', async () => {
    products.list.mockRejectedValueOnce(new Error('SECRET_DETAILS'));
    const response = await request(app.getHttpServer())
      .get('/products')
      .expect(500);
    expect(JSON.stringify(response.body)).not.toContain('SECRET_DETAILS');
  });
  it('filtra catálogo por género a través de HTTP', async () => {
    await request(app.getHttpServer())
      .get('/products?gender=MUJER&limit=2')
      .expect(200);
    expect(products.list).toHaveBeenCalledWith(
      expect.objectContaining({ gender: 'MUJER', limit: 2 }),
      true,
    );
    await request(app.getHttpServer())
      .get('/products?gender=DESCONOCIDO')
      .expect(400);
  });
  it('el filtro HTTP de fechas exige administrador y llega al repositorio', async () => {
    await request(app.getHttpServer())
      .get('/admin/orders?from=2026-10-01')
      .expect(401);
    await request(app.getHttpServer())
      .get('/admin/orders?from=2026-10-01')
      .set('Authorization', 'Bearer client')
      .expect(403);
    await request(app.getHttpServer())
      .get('/admin/orders?from=invalida')
      .set('Authorization', 'Bearer admin')
      .expect(400);
    orders.list.mockResolvedValueOnce({ items: [], nextCursor: null });
    await request(app.getHttpServer())
      .get('/admin/orders?from=2026-10-01&to=2026-10-27&after=previous')
      .set('Authorization', 'Bearer admin')
      .expect(200);
    expect(orders.list).toHaveBeenCalledWith(
      expect.objectContaining({
        from: '2026-10-01',
        to: '2026-10-27',
        after: 'previous',
      }),
      undefined,
    );
  });
  it('registra género y varios colores en el artículo', async () => {
    await request(app.getHttpServer())
      .post('/admin/products')
      .set('Authorization', 'Bearer admin')
      .send({ ...product, gender: 'HOMBRE', colors: ['NEGRO', 'BLANCO'] })
      .expect(201);
    expect(products.create).toHaveBeenCalledWith(
      expect.objectContaining({
        gender: 'HOMBRE',
        colors: ['NEGRO', 'BLANCO'],
      }),
      'admin',
    );
  });
  it('el checkout demo exige cliente autenticado y no admite importes ni tarjetas enviados por el cliente', async () => {
    await request(app.getHttpServer())
      .post('/orders/product1/demo-checkout')
      .expect(401);
    await request(app.getHttpServer())
      .post('/orders/product1/demo-checkout')
      .set('Authorization', 'Bearer admin')
      .expect(403);
    await request(app.getHttpServer())
      .post('/demo-checkouts/checkout1/confirm')
      .set('Authorization', 'Bearer client')
      .send({ scenario: 'APPROVED', amountCents: 1 })
      .expect(400);
    await request(app.getHttpServer())
      .post('/demo-checkouts/checkout1/confirm')
      .set('Authorization', 'Bearer client')
      .send({ scenario: 'APPROVED', cardNumber: '4242424242424242' })
      .expect(400);
    expect(demoGateway.confirm).not.toHaveBeenCalled();
    demoGateway.confirm.mockResolvedValueOnce({
      testMode: true,
      status: 'APPROVED',
    });
    await request(app.getHttpServer())
      .post('/demo-checkouts/checkout1/confirm')
      .set('Authorization', 'Bearer client')
      .send({ scenario: 'APPROVED' })
      .expect(201);
    expect(demoGateway.confirm).toHaveBeenCalledWith(
      'checkout1',
      'APPROVED',
      'client',
    );
  });
});
