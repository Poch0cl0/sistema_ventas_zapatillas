import { ApiProperty } from '@nestjs/swagger';
import { CreateProductDto } from '../../products/dto/product.dto.js';

class ProductImageDto {
  @ApiProperty({ type: String })
  secure_url: string;
}

class ProductModelDto {
  @ApiProperty({ type: String })
  secure_url: string;
  @ApiProperty({ enum: ['glb'] })
  format: string;
  @ApiProperty({ type: Number })
  bytes: number;
}

export class ProductResponseDto extends CreateProductDto {
  @ApiProperty({ type: String })
  id: string;
  @ApiProperty({ type: [ProductImageDto] })
  images: ProductImageDto[];
  @ApiProperty({ type: ProductModelDto, nullable: true })
  model3d: ProductModelDto | null;
}

export class ProductPageDto {
  @ApiProperty({ type: [ProductResponseDto] })
  items: ProductResponseDto[];
  @ApiProperty({ type: String, nullable: true })
  nextCursor: string | null;
}

export class InventoryResponseDto {
  @ApiProperty({ type: String })
  id: string;
  @ApiProperty({ type: String })
  productId: string;
  @ApiProperty({ type: String, example: '40' })
  size: string;
  @ApiProperty({ type: Number })
  available: number;
  @ApiProperty({ type: Number })
  reserved: number;
}

export class InventoryPageDto {
  @ApiProperty({ type: [InventoryResponseDto] })
  items: InventoryResponseDto[];
  @ApiProperty({ type: String, nullable: true })
  nextCursor: string | null;
}

class MovementResponseDto {
  @ApiProperty({ type: String })
  id: string;
  @ApiProperty({ type: String })
  inventoryId: string;
  @ApiProperty({ type: String })
  productId: string;
  @ApiProperty({ type: String })
  size: string;
  @ApiProperty({
    type: String,
    enum: [
      'INGRESO_INICIAL',
      'AJUSTE',
      'RESERVA',
      'LIBERACION_RESERVA',
      'VENTA_PEDIDO',
    ],
  })
  type: string;
  @ApiProperty({ type: Number })
  delta: number;
  @ApiProperty({ type: Number })
  reservedDelta: number;
  @ApiProperty({ type: String, nullable: true })
  orderId: string | null;
  @ApiProperty({ type: Number })
  availableBefore: number;
  @ApiProperty({ type: Number })
  availableAfter: number;
  @ApiProperty({ type: String })
  reason: string;
  @ApiProperty({ type: String })
  actorId: string;
  @ApiProperty({ type: String, nullable: true, format: 'date-time' })
  createdAt: string | null;
}

export class MovementPageDto {
  @ApiProperty({ type: [MovementResponseDto] })
  items: MovementResponseDto[];
  @ApiProperty({ type: String, nullable: true })
  nextCursor: string | null;
}
