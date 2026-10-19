import { Inject, Injectable } from '@nestjs/common';
import { FieldValue } from 'firebase-admin/firestore';
import type { Firestore } from 'firebase-admin/firestore';
import type { DecodedIdToken } from 'firebase-admin/auth';
import { FIREBASE_FIRESTORE } from '../firebase/firebase.providers.js';

@Injectable()
export class UsersRepository {
  constructor(
    @Inject(FIREBASE_FIRESTORE) private readonly firestore: Firestore,
  ) {}

  async findOrCreate(identity: DecodedIdToken) {
    const ref = this.firestore.collection('users').doc(identity.uid);
    return this.firestore.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(ref);
      // Nunca sobrescribir perfiles existentes, especialmente sus roles.
      if (snapshot.exists) return snapshot.data()!;
      const profile = {
        email: identity.email ?? null,
        name: typeof identity.name === 'string' ? identity.name : null,
        role: 'CLIENTE',
      };
      transaction.create(ref, {
        ...profile,
        createdAt: FieldValue.serverTimestamp(),
      });
      return profile;
    });
  }
}
