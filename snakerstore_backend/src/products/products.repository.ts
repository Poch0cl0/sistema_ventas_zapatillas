import {
  BadRequestException,
  Inject,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import type {
  ProductImage,
  ProductModel,
} from '../cloudinary/cloudinary.service.js';
import { FieldValue } from 'firebase-admin/firestore';
import type { Firestore } from 'firebase-admin/firestore';
import { FIREBASE_FIRESTORE } from '../firebase/firebase.providers.js';
import type { PaginationDto } from '../common/dto/pagination.dto.js';
import { firestorePage, publicProduct } from '../common/firestore-page.js';
import type { CreateProductDto, UpdateProductDto } from './dto/product.dto.js';

function productFields(input: UpdateProductDto) {
  const data: Record<string, string | number | boolean> = {};
  for (const key of [
    'name',
    'description',
    'priceCents',
    'category',
    'brand',
    'active',
    'tryOnEnabled',
  ] as const) {
    if (input[key] !== undefined) data[key] = input[key];
  }
  return data;
}

@Injectable()
export class ProductsRepository {
  constructor(
    @Inject(FIREBASE_FIRESTORE) private readonly firestore: Firestore,
  ) {}

  async list(pagination: PaginationDto, onlyActive: boolean) {
    const collection = this.firestore.collection('products');
    const result = await firestorePage(
      onlyActive ? collection.where('active', '==', true) : collection,
      pagination,
    );
    return {
      items: result.docs.map((doc) => publicProduct(doc.id, doc.data())),
      nextCursor: result.nextCursor,
    };
  }

  async find(id: string, onlyActive: boolean) {
    const doc = await this.firestore.collection('products').doc(id).get();
    if (!doc.exists || (onlyActive && doc.data()!.active !== true))
      throw new NotFoundException('Producto no encontrado.');
    return publicProduct(doc.id, doc.data()!);
  }

  async create(input: CreateProductDto, actorId: string) {
    if (input.tryOnEnabled === true)
      throw new BadRequestException(
        'Guarda el producto y carga un modelo 3D antes de habilitar el probador.',
      );
    const ref = this.firestore.collection('products').doc();
    const data = {
      ...productFields(input),
      images: [],
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
      createdBy: actorId,
      updatedBy: actorId,
    };
    await ref.create(data);
    return publicProduct(ref.id, data);
  }

  async availability(id: string) {
    await this.find(id, true);
    const snapshot = await this.firestore
      .collection('inventory')
      .where('productId', '==', id)
      .get();
    return snapshot.docs
      .map((doc) => {
        const data = doc.data();
        return {
          size: data.size,
          available: Number.isSafeInteger(data.available)
            ? Math.max(0, data.available)
            : 0,
        };
      })
      .sort((a, b) => Number(a.size) - Number(b.size));
  }

  async update(id: string, input: UpdateProductDto, actorId: string) {
    const ref = this.firestore.collection('products').doc(id);
    return this.firestore.runTransaction(async (transaction) => {
      const doc = await transaction.get(ref);
      if (!doc.exists) throw new NotFoundException('Producto no encontrado.');
      const current = doc.data()!;
      const hasModel =
        ['urban_sand', 'sport_night'].includes(current.bundledModel) ||
        (current.model3d?.format === 'glb' &&
          typeof current.model3d.secure_url === 'string' &&
          current.model3d.secure_url.startsWith('https://'));
      if (input.tryOnEnabled === true && !hasModel)
        throw new BadRequestException(
          'Carga un modelo 3D antes de habilitar el probador.',
        );
      const changes = {
        ...productFields(input),
        updatedAt: FieldValue.serverTimestamp(),
        updatedBy: actorId,
      };
      transaction.update(ref, changes);
      return publicProduct(id, { ...doc.data(), ...changes });
    });
  }

  async appendImages(
    id: string,
    images: ProductImage[],
    actorId: string,
    maxImages: number,
  ) {
    const ref = this.firestore.collection('products').doc(id);
    return this.firestore.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(ref);
      if (!snapshot.exists)
        throw new NotFoundException('Producto no encontrado.');
      const data = snapshot.data()!;
      const current = Array.isArray(data.images) ? data.images : [];
      if (current.length + images.length > maxImages)
        throw new BadRequestException('Un producto admite hasta 10 imágenes.');
      const changes = {
        images: [...current, ...images],
        updatedAt: FieldValue.serverTimestamp(),
        updatedBy: actorId,
      };
      transaction.update(ref, changes);
      return publicProduct(id, { ...data, ...changes });
    });
  }

  async setModel(id: string, model: ProductModel | null, actorId: string) {
    const ref = this.firestore.collection('products').doc(id);
    return this.firestore.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(ref);
      if (!snapshot.exists)
        throw new NotFoundException('Producto no encontrado.');
      const current = snapshot.data()!;
      const changes = {
        model3d: model,
        tryOnEnabled: false,
        updatedAt: FieldValue.serverTimestamp(),
        updatedBy: actorId,
      };
      transaction.update(ref, changes);
      return {
        product: publicProduct(id, { ...current, ...changes }),
        previous: current.model3d as ProductModel | null | undefined,
      };
    });
  }
}
