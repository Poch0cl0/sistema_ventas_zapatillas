import {
  BadRequestException,
  Inject,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { FieldValue } from 'firebase-admin/firestore';
import type { DocumentData, Firestore } from 'firebase-admin/firestore';
import { FIREBASE_FIRESTORE } from '../firebase/firebase.providers.js';
import { firestorePage } from '../common/firestore-page.js';
import type { PaginationDto } from '../common/dto/pagination.dto.js';
import type {
  CreateDeliveryZoneDto,
  UpdateDeliveryZoneDto,
} from './dto/delivery-zone.dto.js';

function zoneView(id: string, data: DocumentData) {
  return {
    id,
    name: data.name,
    feeCents: data.feeCents,
    active: data.active,
    ...(typeof data.originLat === 'number' && typeof data.originLon === 'number'
      ? { originLat: data.originLat, originLon: data.originLon }
      : {}),
  };
}

function zoneFields(input: UpdateDeliveryZoneDto) {
  if ((input.originLat === undefined) !== (input.originLon === undefined))
    throw new BadRequestException(
      'Envía juntas la latitud y longitud del punto de salida.',
    );
  const fields: Record<string, string | number | boolean> = {};
  for (const key of [
    'name',
    'feeCents',
    'active',
    'originLat',
    'originLon',
  ] as const) {
    if (input[key] !== undefined) fields[key] = input[key];
  }
  return fields;
}

@Injectable()
export class DeliveryZonesRepository {
  constructor(
    @Inject(FIREBASE_FIRESTORE) private readonly firestore: Firestore,
  ) {}

  async list(pagination: PaginationDto, onlyActive: boolean) {
    const collection = this.firestore.collection('delivery_zones');
    const result = await firestorePage(
      onlyActive ? collection.where('active', '==', true) : collection,
      pagination,
    );
    return {
      items: result.docs.map((doc) => zoneView(doc.id, doc.data())),
      nextCursor: result.nextCursor,
    };
  }

  async create(input: CreateDeliveryZoneDto, actorId: string) {
    const ref = this.firestore.collection('delivery_zones').doc();
    const fields = zoneFields(input);
    await ref.create({
      ...fields,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
      createdBy: actorId,
      updatedBy: actorId,
    });
    return zoneView(ref.id, fields);
  }

  async update(id: string, input: UpdateDeliveryZoneDto, actorId: string) {
    const ref = this.firestore.collection('delivery_zones').doc(id);
    return this.firestore.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(ref);
      if (!snapshot.exists)
        throw new NotFoundException('Zona de delivery no encontrada.');
      const changes = {
        ...zoneFields(input),
        updatedAt: FieldValue.serverTimestamp(),
        updatedBy: actorId,
      };
      transaction.update(ref, changes);
      return zoneView(id, { ...snapshot.data(), ...changes });
    });
  }
}
