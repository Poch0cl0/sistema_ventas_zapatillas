import {
  BadRequestException,
  HttpException,
  Inject,
  Injectable,
  Logger,
} from '@nestjs/common';
import { fileTypeFromBuffer } from 'file-type';
import { extname } from 'node:path';
import { CloudinaryService } from '../cloudinary/cloudinary.service.js';
import type { ProductImage } from '../cloudinary/cloudinary.service.js';
import { ProductsRepository } from './products.repository.js';

export const MAX_IMAGE_BYTES = 5 * 1024 * 1024;
export const MAX_UPLOAD_IMAGES = 5;
export const MAX_PRODUCT_IMAGES = 10;

@Injectable()
export class ProductImagesService {
  private readonly logger = new Logger(ProductImagesService.name);
  constructor(
    @Inject(ProductsRepository) private readonly products: ProductsRepository,
    @Inject(CloudinaryService) private readonly cloudinary: CloudinaryService,
  ) {}

  async upload(
    id: string,
    files: Express.Multer.File[] | undefined,
    actorId: string,
  ) {
    if (!files?.length || files.length > MAX_UPLOAD_IMAGES)
      throw new BadRequestException('Selecciona entre 1 y 5 imágenes.');
    const product = await this.products.find(id, false);
    if (product.images.length + files.length > MAX_PRODUCT_IMAGES)
      throw new BadRequestException('Un producto admite hasta 10 imágenes.');
    for (const file of files) {
      if (!file.buffer?.length || file.buffer.length > MAX_IMAGE_BYTES)
        throw new BadRequestException(
          'Cada imagen debe pesar como máximo 5 MiB y no estar vacía.',
        );
      let detected;
      try {
        detected = await fileTypeFromBuffer(file.buffer);
      } catch {
        throw new BadRequestException('No se pudo identificar la imagen.');
      }
      const extensions: Record<string, string[]> = {
        'image/jpeg': ['.jpg', '.jpeg'],
        'image/png': ['.png'],
        'image/webp': ['.webp'],
      };
      if (
        !detected ||
        !extensions[detected.mime]?.includes(
          extname(file.originalname).toLowerCase(),
        ) ||
        file.mimetype !== detected.mime
      ) {
        throw new BadRequestException(
          'Solo se permiten JPEG, PNG o WebP con extensión y contenido coincidentes.',
        );
      }
    }
    const uploaded: ProductImage[] = [];
    try {
      for (const file of files)
        uploaded.push(await this.cloudinary.upload(file.buffer, id));
    } catch (error) {
      await this.cloudinary.cleanup(uploaded);
      throw error;
    }
    try {
      return await this.products.appendImages(
        id,
        uploaded,
        actorId,
        MAX_PRODUCT_IMAGES,
      );
    } catch (error) {
      if (error instanceof HttpException) {
        // Validación transaccional fallida: ninguna referencia llegó a persistirse.
        await this.cloudinary.cleanup(uploaded);
      } else {
        // Un fallo de red puede tener resultado de commit incierto: no borrar imágenes
        // que quizá quedaron referenciadas. Reconciliar los recursos manualmente.
        this.logger.warn(
          'Resultado incierto al vincular imágenes: revisar products.images y recursos de catálogo en Cloudinary antes de reintentar.',
        );
      }
      throw error;
    }
  }
}
