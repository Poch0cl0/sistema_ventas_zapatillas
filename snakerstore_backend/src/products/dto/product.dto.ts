import { ApiProperty, PartialType } from '@nestjs/swagger';
import { Transform } from 'class-transformer';
import { IsBoolean, IsInt, IsString, Length, Max, Min } from 'class-validator';

const trim = ({ value }: { value: unknown }) =>
  typeof value === 'string' ? value.trim() : value;

export class CreateProductDto {
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
}

// Omitidos sí; null no: evita eliminar campos obligatorios durante una edición.
export class UpdateProductDto extends PartialType(CreateProductDto, {
  skipNullProperties: false,
}) {}
