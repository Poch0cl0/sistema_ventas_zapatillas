import { ApiProperty, PartialType } from '@nestjs/swagger';
import { Transform } from 'class-transformer';
import { IsArray, ArrayMaxSize, ArrayUnique, IsIn } from 'class-validator';
import { GENDERS, PRODUCT_COLORS } from './catalog-query.dto.js';
import {
  IsBoolean,
  IsInt,
  IsString,
  ValidateIf,
  Length,
  Max,
  Min,
} from 'class-validator';

const trim = ({ value }: { value: unknown }) =>
  typeof value === 'string' ? value.trim() : value;

export class CreateProductDto {
  @ApiProperty({ required: false, enum: GENDERS })
  @ValidateIf((_object, value) => value !== undefined)
  @IsIn(GENDERS)
  gender?: string;

  @ApiProperty({ required: false, enum: PRODUCT_COLORS, isArray: true })
  @ValidateIf((_object, value) => value !== undefined)
  @IsArray()
  @ArrayMaxSize(12)
  @ArrayUnique()
  @IsIn(PRODUCT_COLORS, { each: true })
  colors?: string[];
  @ApiProperty({ example: 'Zapatilla urbana' })
  @Transform(trim)
  @IsString()
  @Length(1, 120)
  name: string;

  @ApiProperty({ example: 'Zapatilla de uso diario.' })
  @Transform(trim)
  @IsString()
  @Length(1, 2000)
  description: string;

  @ApiProperty({
    example: 25990,
    minimum: 0,
    maximum: 100000000,
    description: 'Entero en céntimos PEN: 25990 = S/ 259.90.',
  })
  @IsInt()
  @Min(0)
  @Max(100000000)
  priceCents: number;

  @ApiProperty({ example: 'Urbano' })
  @Transform(trim)
  @IsString()
  @Length(1, 80)
  category: string;

  @ApiProperty({ example: 'SneakerStore' })
  @Transform(trim)
  @IsString()
  @Length(1, 80)
  brand: string;

  @ApiProperty({ example: true })
  @IsBoolean()
  active: boolean;

  @ApiProperty({
    required: false,
    default: false,
    description:
      'Habilitar el probador visual experimental después de revisar el GLB.',
  })
  @ValidateIf((_object, value) => value !== undefined)
  @IsBoolean()
  tryOnEnabled?: boolean;
}

// Omitidos sí; null no: evita eliminar campos obligatorios durante una edición.
export class UpdateProductDto extends PartialType(CreateProductDto, {
  skipNullProperties: false,
}) {}
