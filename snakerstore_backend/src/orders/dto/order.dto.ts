import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Transform, Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsDefined,
  IsEnum,
  IsInt,
  IsNumber,
  IsObject,
  IsString,
  Length,
  Matches,
  Max,
  Min,
  ValidateIf,
  ValidateNested,
} from 'class-validator';
import { DOCUMENT_ID } from '../../common/dto/pagination.dto.js';

export enum DeliveryType {
  DELIVERY = 'DELIVERY',
  PICKUP = 'PICKUP',
}
export class OrderItemDto {
  @ApiProperty({ type: String })
  @Matches(DOCUMENT_ID)
  productId: string;
  @ApiProperty({ example: '40' })
  @Matches(/^[1-9][0-9]?$/)
  size: string;
  @ApiProperty({ example: 1, minimum: 1, maximum: 100 })
  @IsInt()
  @Min(1)
  @Max(100)
  quantity: number;
}
const trim = ({ value }: { value: unknown }) =>
  typeof value === 'string' ? value.trim() : value;
export class OrderDeliveryDto {
  @ApiProperty({ enum: DeliveryType })
  @IsEnum(DeliveryType)
  type: DeliveryType;
  @ApiProperty({ example: 'Nombre del cliente' })
  @Transform(trim)
  @IsString()
  @Length(2, 120)
  recipientName: string;
  @ApiProperty({ example: '900000000' })
  @Matches(/^9\d{8}$/)
  phone: string;
  @ApiPropertyOptional({ description: 'Obligatorio para DELIVERY.' })
  @ValidateIf(
    (data: OrderDeliveryDto) =>
      data.type === DeliveryType.DELIVERY || data.zoneId !== undefined,
  )
  @Matches(DOCUMENT_ID)
  zoneId?: string;
  @ApiPropertyOptional({ minimum: -90, maximum: 90, description: 'Latitud del pin de entrega; requiere clientLon.' })
  @ValidateIf((data: OrderDeliveryDto) => data.clientLat !== undefined || data.clientLon !== undefined)
  @IsNumber({ allowNaN: false, allowInfinity: false })
  @Min(-90)
  @Max(90)
  clientLat?: number;

  @ApiPropertyOptional({ minimum: -180, maximum: 180, description: 'Longitud del pin de entrega; requiere clientLat.' })
  @ValidateIf((data: OrderDeliveryDto) => data.clientLat !== undefined || data.clientLon !== undefined)
  @IsNumber({ allowNaN: false, allowInfinity: false })
  @Min(-180)
  @Max(180)
  clientLon?: number;
  @ApiPropertyOptional({
    example: 'Av. Ejemplo 123',
    description: 'Obligatoria para DELIVERY sin coordenadas; opcional si hay un pin de entrega.',
  })
  @ValidateIf(
    (data: OrderDeliveryDto) =>
      (data.type === DeliveryType.DELIVERY && data.clientLat === undefined) || data.address !== undefined,
  )
  @Transform(trim)
  @IsString()
  @Length(5, 300)
  address?: string;
  @ApiPropertyOptional({ example: 'Frente al parque' })
  @ValidateIf((data: OrderDeliveryDto) => data.reference !== undefined)
  @Transform(trim)
  @IsString()
  @Length(1, 300)
  reference?: string;
}
export class CreateOrderDto {
  @ApiProperty({ type: [OrderItemDto], minItems: 1, maxItems: 30 })
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(30)
  @ValidateNested({ each: true })
  @Type(() => OrderItemDto)
  items: OrderItemDto[];
  @ApiProperty({ type: OrderDeliveryDto })
  @IsDefined()
  @IsObject()
  @ValidateNested()
  @Type(() => OrderDeliveryDto)
  delivery: OrderDeliveryDto;
}
export enum FulfillmentStatus {
  PREPARANDO = 'PREPARANDO',
  LISTO_RECOJO = 'LISTO_RECOJO',
  EN_REPARTO = 'EN_REPARTO',
  ENTREGADO = 'ENTREGADO',
}
export class FulfillmentDto {
  @ApiProperty({ enum: FulfillmentStatus })
  @IsEnum(FulfillmentStatus)
  status: FulfillmentStatus;
}
