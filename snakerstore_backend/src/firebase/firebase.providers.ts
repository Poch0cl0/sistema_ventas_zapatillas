import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { ConfigService } from '@nestjs/config';
import { cert, getApps, initializeApp } from 'firebase-admin/app';
import type { App } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { FIREBASE_PROJECT_ID } from '../config/environment.js';

export const FIREBASE_APP = Symbol('FIREBASE_APP');
export const FIREBASE_AUTH = Symbol('FIREBASE_AUTH');
export const FIREBASE_FIRESTORE = Symbol('FIREBASE_FIRESTORE');

export function createFirebaseApp(config: ConfigService): App {
  const projectId = config.getOrThrow<string>('FIREBASE_PROJECT_ID');
  if (projectId !== FIREBASE_PROJECT_ID) {
    throw new Error('El proyecto Firebase no corresponde a SneakerStore.');
  }
  const existing = getApps().find((app) => app.name === '[DEFAULT]');
  if (existing) {
    if (existing.options.projectId !== projectId) {
      throw new Error(
        'La aplicación Firebase existente pertenece a otro proyecto.',
      );
    }
    return existing;
  }

  // Las rutas relativas se resuelven desde la carpeta de ejecución del backend.
  let account: unknown;
  try {
    account = JSON.parse(
      readFileSync(
        resolve(config.getOrThrow<string>('FIREBASE_SERVICE_ACCOUNT')),
        'utf8',
      ),
    );
  } catch {
    throw new Error(
      'No se pudo leer la cuenta de servicio Firebase como JSON.',
    );
  }
  if (
    !account ||
    typeof account !== 'object' ||
    !('project_id' in account) ||
    account.project_id !== projectId ||
    !('client_email' in account) ||
    typeof account.client_email !== 'string' ||
    !account.client_email ||
    !('private_key' in account) ||
    typeof account.private_key !== 'string' ||
    !account.private_key
  ) {
    throw new Error(
      'La cuenta de servicio Firebase es inválida o pertenece a otro proyecto.',
    );
  }
  try {
    return initializeApp({
      projectId,
      credential: cert({
        projectId,
        clientEmail: account.client_email,
        privateKey: account.private_key,
      }),
    });
  } catch {
    // No propagar errores que puedan incluir contenido de las credenciales.
    throw new Error(
      'No se pudo inicializar Firebase Admin con la cuenta de servicio configurada.',
    );
  }
}

export const firebaseProviders = [
  {
    provide: FIREBASE_APP,
    inject: [ConfigService],
    useFactory: createFirebaseApp,
  },
  {
    provide: FIREBASE_AUTH,
    inject: [FIREBASE_APP],
    useFactory: (app: App) => getAuth(app),
  },
  {
    provide: FIREBASE_FIRESTORE,
    inject: [FIREBASE_APP],
    useFactory: (app: App) => getFirestore(app),
  },
];
