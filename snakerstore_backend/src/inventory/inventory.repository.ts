import {
  ConflictException,
  Inject,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { FieldValue } from 'firebase-admin/firestore';
import type { DocumentData, Firestore } from 'firebase-admin/firestore';
import { FIREBASE_FIRESTORE } from '../firebase/firebase.providers.js';
import { firestorePage } from '../common/firestore-page.js';
import type {
  AdjustInventoryDto,
  CreateInventoryDto,
  InventoryQueryDto,
  MovementQueryDto,
} from './dto/inventory.dto.js';

function inventoryView(id: string, data: DocumentData) {
  return {
    id,
    productId: data.productId,
    size: data.size,
    available: data.available,
    reserved: data.reserved,
  };
}

export function adjustedAvailable(
  available: unknown,
  reserved: unknown,
  delta: number,
): number {
  if (
    !Number.isSafeInteger(available) ||
    !Number.isSafeInteger(reserved) ||
    Number(available) < 0 ||
    Number(reserved) < 0
  ) {
    throw new ConflictException('El inventario existente requiere revisión.');
  }
  const next = Number(available) + delta;
  if (!Number.isSafeInteger(next) || next < 0 || next > 1000000)
    throw new ConflictException(
      'Stock disponible insuficiente o fuera del límite permitido.',
    );
  return next;
}

@Injectable()
export class InventoryRepository {
  constructor(
    @Inject(FIREBASE_FIRESTORE) private readonly firestore: Firestore,
  ) {}

  async list(query: InventoryQueryDto) {
    const collection = this.firestore.collection('inventory');
    const result = await firestorePage(
      query.productId
        ? collection.where('productId', '==', query.productId)
        : collection,
      query,
    );
    return {
      items: result.docs.map((doc) => inventoryView(doc.id, doc.data())),
      nextCursor: result.nextCursor,
    };
  }

  async movements(query: MovementQueryDto) {
    const collection = this.firestore.collection('inventory_movements');
    const result = await firestorePage(
      query.inventoryId
        ? collection.where('inventoryId', '==', query.inventoryId)
        : collection,
      query,
    );
    return {
      items: result.docs.map((doc) => {
        const data = doc.data();
        return {
          id: doc.id,
          inventoryId: data.inventoryId,
          productId: data.productId,
          size: data.size,
          type: data.type,
          delta: data.delta,
          reservedDelta: data.reservedDelta ?? 0,
          orderId: data.orderId ?? null,
          availableBefore: data.availableBefore,
          availableAfter: data.availableAfter,
          reason: data.reason,
          actorId: data.actorId,
          createdAt: data.createdAt?.toDate()?.toISOString() ?? null,
        };
      }),
      nextCursor: result.nextCursor,
    };
  }

  async create(input: CreateInventoryDto, actorId: string) {
    const id = `${input.productId}_${input.size}`;
    const ref = this.firestore.collection('inventory').doc(id);
    const product = this.firestore.collection('products').doc(input.productId);
    const movement = this.firestore.collection('inventory_movements').doc();
    return this.firestore.runTransaction(async (transaction) => {
      const [productSnapshot, inventorySnapshot] = await transaction.getAll(
        product,
        ref,
      );
      if (!productSnapshot.exists)
        throw new NotFoundException('Producto no encontrado.');
      if (inventorySnapshot.exists)
        throw new ConflictException(
          'Esta talla ya existe. Usa el ajuste de inventario.',
        );
      const data = {
        productId: input.productId,
        size: input.size,
        available: input.quantity,
        reserved: 0,
      };
      transaction.create(ref, {
        ...data,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      transaction.create(movement, {
        inventoryId: id,
        productId: input.productId,
        size: input.size,
        type: 'INGRESO_INICIAL',
        delta: input.quantity,
        availableBefore: 0,
        availableAfter: input.quantity,
        reason: input.reason?.trim() || 'Ajuste de inventario',
        actorId,
        createdAt: FieldValue.serverTimestamp(),
      });
      return inventoryView(id, data);
    });
  }

  async adjust(id: string, input: AdjustInventoryDto, actorId: string) {
    const ref = this.firestore.collection('inventory').doc(id);
    const movement = this.firestore.collection('inventory_movements').doc();
    return this.firestore.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(ref);
      if (!snapshot.exists)
        throw new NotFoundException('Inventario no encontrado.');
      const data = snapshot.data()!;
      const available = adjustedAvailable(
        data.available,
        data.reserved,
        input.delta,
      );
      transaction.update(ref, {
        available,
        updatedAt: FieldValue.serverTimestamp(),
      });
      transaction.create(movement, {
        inventoryId: id,
        productId: data.productId,
        size: data.size,
        type: 'AJUSTE',
        delta: input.delta,
        availableBefore: data.available,
        availableAfter: available,
        reason: input.reason?.trim() || 'Ajuste de inventario',
        actorId,
        createdAt: FieldValue.serverTimestamp(),
      });
      return inventoryView(id, { ...data, available });
    });
  }
}
