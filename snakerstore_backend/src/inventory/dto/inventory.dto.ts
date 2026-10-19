import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Transform } from 'class-transformer';
import {
  IsInt,
  IsOptional,
  IsString,
  Length,
  Matches,
  Max,
  Min,
  NotEquals,
} from 'class-validator';
import { DOCUMENT_ID, PaginationDto } from '../../common/dto/pagination.dto.js';

export class CreateInventoryDto {
  @ApiProperty({
    description: 'ID de producto devuelto por POST /admin/products.',
  })
  @Matches(DOCUMENT_ID)
  productId: string;

  @ApiProperty({
    example: '40',
    description: 'Talla EU como string entero, sin ceros iniciales.',
  })
  @Matches(/^[1-9][0-9]?$/)
  size: string;

  @ApiProperty({ example: 10, minimum: 0, maximum: 1000000 })
  @IsInt()
  @Min(0)
  @Max(1000000)
  quantity: number;

  @ApiPropertyOptional({ example: 'Ingreso inicial de almacén' })
  @IsOptional()
  @Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? value.trim() : value,
  )
  @IsString()
  @Length(0, 300)
  reason?: string;
}

export class AdjustInventoryDto {
  @ApiProperty({
    example: 5,
    minimum: -1000000,
    maximum: 1000000,
    description: 'Unidades a sumar o restar a available; no modifica reserved.',
  })
  @IsInt()
  @Min(-1000000)
  @Max(1000000)
  @NotEquals(0)
  delta: number;

  @ApiPropertyOptional({ example: 'Reposición de almacén' })
  @IsOptional()
  @Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? value.trim() : value,
  )
  @IsString()
  @Length(0, 300)
  reason?: string;
}

export class InventoryQueryDto extends PaginationDto {
  @ApiPropertyOptional({ description: 'Filtrar por producto.' })
  @IsOptional()
  @Matches(DOCUMENT_ID)
  productId?: string;
}

export class MovementQueryDto extends PaginationDto {
  @ApiPropertyOptional({ description: 'Filtrar por ID de inventario.' })
  @IsOptional()
  @Matches(/^[A-Za-z0-9_-]{1,128}_[1-9][0-9]?$/)
  inventoryId?: string;
}

export class InventoryIdDto {
  @ApiProperty({
    type: String,
    description: 'ID devuelto al crear inventario: producto_talla.',
  })
  @Matches(/^[A-Za-z0-9_-]{1,128}_[1-9][0-9]?$/)
  id: string;
}
