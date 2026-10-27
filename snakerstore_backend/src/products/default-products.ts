import { Inject, Injectable, type OnModuleInit } from '@nestjs/common';
import { FieldValue, type Firestore } from 'firebase-admin/firestore';
import { FIREBASE_FIRESTORE } from '../firebase/firebase.providers.js';

export const DEFAULT_PRODUCTS = [
  {
    id: 'demo-sport-night',
    bundledModel: 'sport_night',
    name: 'Sport Night',
    category: 'Deportivo',
    priceCents: 22900,
    description:
      'Diseño de demostración SneakerStore en azul oscuro con detalles lima. Incluye modelo 3D y probador visual con cámara.',
  },
  {
    id: 'demo-urban-sand',
    bundledModel: 'urban_sand',
    name: 'Urban Sand',
    category: 'Urbano',
    priceCents: 19900,
    description:
      'Diseño de demostración SneakerStore en arena con detalles naranja. Incluye modelo 3D y probador visual con cámara.',
  },
] as const;

// Create only missing IDs. Never overwrite administrator edits or create fake stock.
export async function ensureDefaultProducts(firestore: Firestore) {
  await firestore.runTransaction(async (transaction) => {
    const refs = DEFAULT_PRODUCTS.map((p) =>
      firestore.collection('products').doc(p.id),
    );
    const snapshots = await transaction.getAll(...refs);
    snapshots.forEach((snapshot, i) => {
      if (snapshot.exists) return;
      const { id: _id, ...product } = DEFAULT_PRODUCTS[i];
      transaction.create(refs[i], {
        ...product,
        brand: 'SneakerStore Demo',
        active: true,
        tryOnEnabled: true,
        images: [],
        model3d: null,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        createdBy: 'system:default-products',
        updatedBy: 'system:default-products',
      });
    });
  });
}

@Injectable()
export class DefaultProductsService implements OnModuleInit {
  constructor(
    @Inject(FIREBASE_FIRESTORE) private readonly firestore: Firestore,
  ) {}
  async onModuleInit() {
    await ensureDefaultProducts(this.firestore);
  }
}
