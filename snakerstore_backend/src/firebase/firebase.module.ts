import { Global, Module } from '@nestjs/common';
import {
  FIREBASE_APP,
  FIREBASE_AUTH,
  FIREBASE_FIRESTORE,
  firebaseProviders,
} from './firebase.providers.js';

@Global()
@Module({
  providers: firebaseProviders,
  exports: [FIREBASE_APP, FIREBASE_AUTH, FIREBASE_FIRESTORE],
})
export class FirebaseModule {}
