import {
  Inject,
  Injectable,
  Logger,
  ServiceUnavailableException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { v2 as cloudinary } from 'cloudinary';
import { randomUUID } from 'node:crypto';

export interface ProductImage {
  secure_url: string;
  public_id: string;
}

export interface ProductModel extends ProductImage {
  format: 'glb';
  bytes: number;
}

@Injectable()
export class CloudinaryService {
  private readonly logger = new Logger(CloudinaryService.name);
  constructor(@Inject(ConfigService) private readonly config: ConfigService) {}

  private options() {
    const cloud_name = this.config.get<string>('CLOUDINARY_CLOUD_NAME');
    const api_key = this.config.get<string>('CLOUDINARY_API_KEY');
    const api_secret = this.config.get<string>('CLOUDINARY_API_SECRET');
    if (!cloud_name || !api_key || !api_secret)
      throw new ServiceUnavailableException('Cloudinary no está configurado.');
    return { cloud_name, api_key, api_secret, secure: true };
  }

  upload(buffer: Buffer, productId: string): Promise<ProductImage> {
    const options = this.options();
    return new Promise((resolve, reject) => {
      const stream = cloudinary.uploader.upload_stream(
        {
          ...options,
          public_id: `sneakerstore/products/${productId}/${randomUUID()}`,
          resource_type: 'image',
          type: 'upload',
          overwrite: false,
          allowed_formats: ['jpg', 'png', 'webp'],
          timeout: 60000,
          tags: ['sneakerstore-product'],
        },
        (error, result) => {
          if (error || !result?.secure_url || !result.public_id) {
            reject(
              new ServiceUnavailableException(
                'No se pudo subir la imagen a Cloudinary.',
              ),
            );
          } else
            resolve({
              secure_url: result.secure_url,
              public_id: result.public_id,
            });
        },
      );
      stream.on('error', () =>
        reject(
          new ServiceUnavailableException(
            'No se pudo transferir la imagen a Cloudinary.',
          ),
        ),
      );
      stream.end(buffer);
    });
  }

  uploadModel(buffer: Buffer, productId: string): Promise<ProductModel> {
    const options = this.options();
    return new Promise((resolve, reject) => {
      const stream = cloudinary.uploader.upload_stream(
        {
          ...options,
          resource_type: 'raw',
          public_id: `sneakerstore/products/${productId}/models/${randomUUID()}.glb`,
          type: 'upload',
          overwrite: false,
          timeout: 60000,
          tags: ['sneakerstore-model'],
        },
        (error, result) => {
          if (error || !result?.secure_url || !result.public_id)
            reject(
              new ServiceUnavailableException(
                'No se pudo subir el modelo 3D a Cloudinary.',
              ),
            );
          else
            resolve({
              secure_url: result.secure_url,
              public_id: result.public_id,
              format: 'glb',
              bytes: buffer.length,
            });
        },
      );
      stream.on('error', () =>
        reject(
          new ServiceUnavailableException(
            'No se pudo transferir el modelo 3D.',
          ),
        ),
      );
      stream.end(buffer);
    });
  }

  async cleanupModel(model: ProductImage) {
    try {
      const options = {
        ...this.options(),
        resource_type: 'raw' as const,
        type: 'upload' as const,
        invalidate: true,
        timeout: 60000,
      };
      const result = await cloudinary.uploader.destroy(model.public_id, options);
      if (result.result !== 'ok' && result.result !== 'not found')
        throw new Error('cleanup');
    } catch {
      this.logger.warn(
        'No se pudo eliminar un modelo 3D sin uso; revisar recursos de catálogo en Cloudinary.',
      );
    }
  }

  async cleanup(images: ProductImage[]) {
    const results = await Promise.allSettled(
      images.map(async (image) => {
        const options = {
          ...this.options(),
          resource_type: 'image' as const,
          type: 'upload' as const,
          invalidate: true,
          timeout: 60000,
        };
        const result = await cloudinary.uploader.destroy(
          image.public_id,
          options,
        );
        if (result.result !== 'ok' && result.result !== 'not found')
          throw new Error('cleanup');
      }),
    );
    if (results.some((result) => result.status === 'rejected')) {
      this.logger.warn(
        'No se pudo completar la limpieza de imágenes; revisar recursos de catálogo no vinculados en Cloudinary.',
      );
    }
  }
}
