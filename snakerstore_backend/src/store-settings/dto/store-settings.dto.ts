import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Transform, Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsDefined,
  IsEnum,
  IsObject,
  IsString,
  Length,
  Matches,
  ValidateIf,
  ValidateNested,
} from 'class-validator';

const trim = ({ value }: { value: unknown }) =>
  typeof value === 'string' ? value.trim() : value;
export enum PaymentMethod {
  YAPE = 'YAPE',
  PLIN = 'PLIN',
  TRANSFERENCIA = 'TRANSFERENCIA',
}

export class PickupSettingsDto {
  @ApiProperty({ example: true })
  @IsBoolean()
  enabled: boolean;

  @ApiProperty({
    example: 'Dirección pública de tu tienda',
    description: 'Dirección de recojo; no es la dirección del cliente.',
  })
  @Transform(trim)
  @IsString()
  @Length(5, 300)
  address: string;

  @ApiProperty({ example: 'Presentar el número del pedido al recoger.' })
  @Transform(trim)
  @IsString()
  @Length(1, 1000)
  instructions: string;

  @ApiProperty({
    example: 'Lunes a sábado, 10:00 a 19:00',
    description: 'Horario informativo; no automatiza la disponibilidad.',
  })
  @Transform(trim)
  @IsString()
  @Length(1, 300)
  openingHours: string;
}

export class PaymentMethodSettingsDto {
  @ApiProperty({ enum: PaymentMethod })
  @IsEnum(PaymentMethod)
  method: PaymentMethod;

  @ApiProperty({ example: true })
  @IsBoolean()
  enabled: boolean;

  @ApiProperty({ example: 'Titular de la cuenta de la tienda' })
  @Transform(trim)
  @IsString()
  @Length(1, 120)
  holderName: string;

  @ApiPropertyOptional({
    example: '900000000',
    description:
      'Obligatorio para YAPE/PLIN habilitados. Celular peruano de 9 dígitos.',
  })
  @ValidateIf(
    (item: PaymentMethodSettingsDto) =>
      item.phone !== undefined ||
      (item.enabled === true &&
        (item.method === PaymentMethod.YAPE ||
          item.method === PaymentMethod.PLIN)),
  )
  @Transform(trim)
  @Matches(/^9\d{8}$/)
  phone?: string;

  @ApiPropertyOptional({
    example: 'Nombre del banco',
    description: 'Obligatorio para TRANSFERENCIA habilitada.',
  })
  @ValidateIf(
    (item: PaymentMethodSettingsDto) =>
      item.bankName !== undefined ||
      (item.enabled === true && item.method === PaymentMethod.TRANSFERENCIA),
  )
  @Transform(trim)
  @IsString()
  @Length(1, 120)
  bankName?: string;

  @ApiPropertyOptional({
    example: '00000000000000',
    description: 'Obligatorio para TRANSFERENCIA habilitada. Solo dígitos.',
  })
  @ValidateIf(
    (item: PaymentMethodSettingsDto) =>
      item.accountNumber !== undefined ||
      (item.enabled === true && item.method === PaymentMethod.TRANSFERENCIA),
  )
  @Transform(trim)
  @Matches(/^\d{6,30}$/)
  accountNumber?: string;

  @ApiPropertyOptional({
    example: '00000000000000000000',
    description: 'CCI opcional de 20 dígitos.',
  })
  @ValidateIf((item: PaymentMethodSettingsDto) => item.cci !== undefined)
  @Transform(trim)
  @Matches(/^\d{20}$/)
  cci?: string;
}

export class PutStoreSettingsDto {
  @ApiProperty({ example: 'SneakerStore' })
  @Transform(trim)
  @IsString()
  @Length(1, 120)
  storeName: string;

  @ApiProperty({ type: PickupSettingsDto })
  @IsDefined()
  @IsObject()
  @ValidateNested()
  @Type(() => PickupSettingsDto)
  pickup: PickupSettingsDto;

  @ApiProperty({
    type: [PaymentMethodSettingsDto],
    maxItems: 3,
    description:
      'Máximo una entrada por método. Lista vacía deshabilita todos los métodos.',
  })
  @IsArray()
  @ArrayMaxSize(3)
  @ValidateNested({ each: true })
  @Type(() => PaymentMethodSettingsDto)
  paymentMethods: PaymentMethodSettingsDto[];

  @ApiProperty({
    example: 'El pago se verifica manualmente. La reserva dura 24 horas.',
  })
  @Transform(trim)
  @IsString()
  @Length(1, 2000)
  publicNotes: string;
}

export class StoreSettingsResponseDto extends PutStoreSettingsDto {
  @ApiProperty({ enum: ['PEN'], example: 'PEN' })
  currency: string;
}
