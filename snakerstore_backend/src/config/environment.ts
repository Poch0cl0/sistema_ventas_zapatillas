export const FIREBASE_PROJECT_ID = 'snakerstore-e74cd';

export function validateEnvironment(config: Record<string, unknown>) {
  const cloudinaryKeys = [
    'CLOUDINARY_CLOUD_NAME',
    'CLOUDINARY_API_KEY',
    'CLOUDINARY_API_SECRET',
  ] as const;
  const hasCloudinary = cloudinaryKeys.some((key) => config[key] !== undefined);
  if (hasCloudinary) {
    for (const key of cloudinaryKeys) {
      if (
        typeof config[key] !== 'string' ||
        !config[key].trim() ||
        /\s/.test(config[key])
      ) {
        throw new Error(`${key} debe estar configurada sin espacios.`);
      }
    }
  }
  const port = Number(config.PORT ?? 3000);
  if (!Number.isInteger(port) || port < 1 || port > 65535) {
    throw new Error('PORT debe ser un entero entre 1 y 65535.');
  }
  if (config.FIREBASE_PROJECT_ID !== FIREBASE_PROJECT_ID) {
    throw new Error(
      'FIREBASE_PROJECT_ID no corresponde al proyecto SneakerStore.',
    );
  }
  const serviceAccount = config.FIREBASE_SERVICE_ACCOUNT;
  if (typeof serviceAccount !== 'string' || !serviceAccount.trim()) {
    throw new Error(
      'FIREBASE_SERVICE_ACCOUNT debe indicar la ruta de la cuenta de servicio.',
    );
  }
  return {
    ...config,
    PORT: port,
    FIREBASE_SERVICE_ACCOUNT: serviceAccount.trim(),
  };
}
