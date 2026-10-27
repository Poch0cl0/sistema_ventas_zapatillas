import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsIn, IsOptional } from 'class-validator';
import { PaginationDto } from '../../common/dto/pagination.dto.js';

export const GENDERS = [
  'HOMBRE',
  'MUJER',
  'UNISEX',
  'SIN_ESPECIFICAR',
] as const;
export const PRODUCT_COLORS = [
  'NEGRO',
  'BLANCO',
  'GRIS',
  'AZUL',
  'ROJO',
  'VERDE',
  'AMARILLO',
  'NARANJA',
  'ROSA',
  'MORADO',
  'BEIGE',
  'MARRON',
] as const;
export class CatalogQueryDto extends PaginationDto {
  @ApiPropertyOptional({ enum: GENDERS })
  @IsOptional()
  @IsIn(GENDERS)
  gender?: string;
}
