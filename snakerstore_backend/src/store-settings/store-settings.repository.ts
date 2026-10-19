import { Inject, Injectable, NotFoundException } from '@nestjs/common';
import { FieldValue } from 'firebase-admin/firestore';
import type { DocumentData, Firestore } from 'firebase-admin/firestore';
import { FIREBASE_FIRESTORE } from '../firebase/firebase.providers.js';
import type { PutStoreSettingsDto } from './dto/store-settings.dto.js';

function paymentView(data: DocumentData) {
  const payment: DocumentData = {
    method: data.method,
    enabled: data.enabled,
    holderName: data.holderName,
  };
  for (const key of ['phone', 'bankName', 'accountNumber', 'cci']) {
    if (typeof data[key] === 'string') payment[key] = data[key];
  }
  return payment;
}

function settingsView(data: DocumentData, onlyEnabled: boolean) {
  const methods: DocumentData[] = Array.isArray(data.paymentMethods)
    ? data.paymentMethods
    : [];
  return {
    storeName: data.storeName,
    currency: 'PEN',
    pickup: {
      enabled: data.pickup?.enabled === true,
      address: data.pickup?.address,
      instructions: data.pickup?.instructions,
      openingHours: data.pickup?.openingHours,
    },
    paymentMethods: methods
      .filter((item) => !onlyEnabled || item.enabled === true)
      .map(paymentView),
    publicNotes: data.publicNotes,
  };
}

@Injectable()
export class StoreSettingsRepository {
  constructor(
    @Inject(FIREBASE_FIRESTORE) private readonly firestore: Firestore,
  ) {}

  async get(onlyEnabled: boolean) {
    const snapshot = await this.firestore
      .collection('store_settings')
      .doc('main')
      .get();
    if (!snapshot.exists)
      throw new NotFoundException('La tienda aún no tiene configuración.');
    return settingsView(snapshot.data()!, onlyEnabled);
  }

  async put(input: PutStoreSettingsDto, actorId: string) {
    const ref = this.firestore.collection('store_settings').doc('main');
    const fields = {
      storeName: input.storeName,
      currency: 'PEN',
      pickup: {
        enabled: input.pickup.enabled,
        address: input.pickup.address,
        instructions: input.pickup.instructions,
        openingHours: input.pickup.openingHours,
      },
      paymentMethods: input.paymentMethods.map(paymentView),
      publicNotes: input.publicNotes,
    };
    return this.firestore.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(ref);
      const audit = {
        updatedAt: FieldValue.serverTimestamp(),
        updatedBy: actorId,
      };
      if (snapshot.exists) {
        // Sustituye íntegramente los campos editables, conservando otros campos y auditoría de creación.
        transaction.update(ref, { ...fields, ...audit });
      } else {
        transaction.create(ref, {
          ...fields,
          ...audit,
          createdAt: FieldValue.serverTimestamp(),
          createdBy: actorId,
        });
      }
      return settingsView(fields, false);
    });
  }
}
