import { ApiProperty, ApiPropertyOptional, PartialType } from '@nestjs/swagger';
import { Transform } from 'class-transformer';
import {
  IsBoolean,
  IsInt,
  IsNumber,
  IsString,
  Length,
  Max,
  Min,
  ValidateIf,
} from 'class-validator';

export class CreateDeliveryZoneDto {
  @ApiProperty({ example: 'Zona centro' })
  @Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? value.trim() : value,
  )
  @IsString()
  @Length(1, 100)
  name: string;

  @ApiProperty({
    example: 800,
    minimum: 0,
    maximum: 1000000,
    description: 'Tarifa en céntimos PEN: 800 = S/ 8.00.',
  })
  @IsInt()
  @Min(0)
  @Max(1000000)
  feeCents: number;

  @ApiProperty({ example: true })
  @IsBoolean()
  active: boolean;

  @ApiPropertyOptional({
    minimum: -90,
    maximum: 90,
    description: 'Latitud del punto de salida de esta zona.',
  })
  @ValidateIf(
    (value: CreateDeliveryZoneDto) =>
      value.originLat !== undefined || value.originLon !== undefined,
  )
  @IsNumber({ allowNaN: false, allowInfinity: false })
  @Min(-90)
  @Max(90)
  originLat?: number;

  @ApiPropertyOptional({
    minimum: -180,
    maximum: 180,
    description: 'Longitud del punto de salida de esta zona.',
  })
  @ValidateIf(
    (value: CreateDeliveryZoneDto) =>
      value.originLat !== undefined || value.originLon !== undefined,
  )
  @IsNumber({ allowNaN: false, allowInfinity: false })
  @Min(-180)
  @Max(180)
  originLon?: number;
}

export class UpdateDeliveryZoneDto extends PartialType(CreateDeliveryZoneDto, {
  skipNullProperties: false,
}) {}

export class DeliveryZoneResponseDto extends CreateDeliveryZoneDto {
  @ApiProperty({ type: String })
  id: string;
}

export class DeliveryZonePageDto {
  @ApiProperty({ type: [DeliveryZoneResponseDto] })
  items: DeliveryZoneResponseDto[];

  @ApiProperty({ type: String, nullable: true })
  nextCursor: string | null;
}
