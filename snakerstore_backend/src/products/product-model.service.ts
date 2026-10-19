import {
  BadRequestException,
  HttpException,
  Inject,
  Injectable,
  Logger,
} from '@nestjs/common';
import { extname } from 'node:path';
import { CloudinaryService } from '../cloudinary/cloudinary.service.js';
import { ProductsRepository } from './products.repository.js';

export const MAX_MODEL_BYTES = 10 * 1024 * 1024;

// Accept only GLB 2.0 with embedded geometry/textures: no external resource URLs.
function validateModel(file: Express.Multer.File | undefined): Buffer {
  if (
    !file?.buffer?.length ||
    file.buffer.length > MAX_MODEL_BYTES ||
    extname(file.originalname).toLowerCase() !== '.glb'
  )
    throw new BadRequestException(
      'Selecciona un archivo .glb de hasta 10 MiB.',
    );
  const bytes = file.buffer;
  const invalid = () =>
    new BadRequestException(
      'El modelo debe ser GLB 2.0 válido con geometría y texturas incluidas.',
    );
  if (
    bytes.length < 28 ||
    bytes.toString('ascii', 0, 4) !== 'glTF' ||
    bytes.readUInt32LE(4) !== 2 ||
    bytes.readUInt32LE(8) !== bytes.length
  )
    throw invalid();
  let offset = 12;
  let metadata: Record<string, unknown> | undefined;
  let binaryBytes = 0;
  while (offset < bytes.length) {
    if (offset + 8 > bytes.length) throw invalid();
    const length = bytes.readUInt32LE(offset);
    const type = bytes.readUInt32LE(offset + 4);
    if (!length || length % 4 || offset + 8 + length > bytes.length)
      throw invalid();
    if (offset === 12 && type !== 0x4e4f534a) throw invalid();
    if (type === 0x4e4f534a) {
      if (metadata || length > 2 * 1024 * 1024) throw invalid();
      try {
        const parsed: unknown = JSON.parse(
          bytes.toString('utf8', offset + 8, offset + 8 + length),
        );
        if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed))
          throw invalid();
        metadata = parsed as Record<string, unknown>;
      } catch {
        throw invalid();
      }
    } else if (type === 0x004e4942) {
      if (binaryBytes) throw invalid();
      binaryBytes = length;
    } else throw invalid();
    offset += 8 + length;
  }
  const asset = metadata?.asset as { version?: unknown } | undefined;
  const buffers = metadata?.buffers as
    { uri?: unknown; byteLength?: unknown }[] | undefined;
  const images = metadata?.images as
    { uri?: unknown; bufferView?: unknown }[] | undefined;
  if (
    !metadata ||
    asset?.version !== '2.0' ||
    !Array.isArray(metadata.meshes) ||
    !metadata.meshes.length ||
    !Array.isArray(buffers) ||
    buffers.length !== 1 ||
    !buffers[0] ||
    buffers[0].uri !== undefined ||
    typeof buffers[0].byteLength !== 'number' ||
    !Number.isSafeInteger(buffers[0].byteLength) ||
    buffers[0].byteLength <= 0 ||
    buffers[0].byteLength > binaryBytes ||
    binaryBytes - buffers[0].byteLength > 3
  )
    throw invalid();
  if (
    images !== undefined &&
    (!Array.isArray(images) ||
      images.some(
        (image) =>
          !image ||
          image.uri !== undefined ||
          !Number.isSafeInteger(image.bufferView) ||
          Number(image.bufferView) < 0,
      ))
  )
    throw invalid();
  return bytes;
}

@Injectable()
export class ProductModelService {
  private readonly logger = new Logger(ProductModelService.name);
  constructor(
    @Inject(ProductsRepository) private readonly products: ProductsRepository,
    @Inject(CloudinaryService) private readonly cloudinary: CloudinaryService,
  ) {}

  async upload(
    id: string,
    file: Express.Multer.File | undefined,
    actorId: string,
  ) {
    const bytes = validateModel(file);
    await this.products.find(id, false);
    const model = await this.cloudinary.uploadModel(bytes, id);
    let result: Awaited<ReturnType<ProductsRepository['setModel']>>;
    try {
      result = await this.products.setModel(id, model, actorId);
    } catch (error) {
      // A transport error can have an uncertain commit outcome; preserve the asset.
      if (error instanceof HttpException)
        await this.cloudinary.cleanupModel(model);
      else
        this.logger.warn(
          'Vinculación de modelo 3D incierta; revisar products.model3d antes de reintentar.',
        );
      throw error;
    }
    if (result.previous?.public_id)
      await this.cloudinary.cleanupModel(result.previous);
    return result.product;
  }

  async remove(id: string, actorId: string) {
    const result = await this.products.setModel(id, null, actorId);
    if (result.previous?.public_id)
      await this.cloudinary.cleanupModel(result.previous);
    return result.product;
  }
}
