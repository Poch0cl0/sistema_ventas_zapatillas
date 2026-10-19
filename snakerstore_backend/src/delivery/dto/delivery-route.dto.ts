import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsNumber, Matches, Max, Min, ValidateIf } from 'class-validator';
import { DOCUMENT_ID } from '../../common/dto/pagination.dto.js';

export class DeliveryRouteDto {
  @ApiProperty({ minimum: -180, maximum: 180 })
  @IsNumber({ allowNaN: false, allowInfinity: false })
  @Min(-180)
  @Max(180)
  clientLon: number;

  @ApiProperty({ minimum: -90, maximum: 90 })
  @IsNumber({ allowNaN: false, allowInfinity: false })
  @Min(-90)
  @Max(90)
  clientLat: number;

  @ApiPropertyOptional({
    description: 'Zona activa que determina el origen durante el checkout.',
  })
  @ValidateIf((value: DeliveryRouteDto) => value.zoneId !== undefined)
  @Matches(DOCUMENT_ID)
  zoneId?: string;

  @ApiPropertyOptional({
    description:
      'Pedido propio (o como administrador); usa las coordenadas guardadas.',
  })
  @ValidateIf((value: DeliveryRouteDto) => value.orderId !== undefined)
  @Matches(DOCUMENT_ID)
  orderId?: string;
}
