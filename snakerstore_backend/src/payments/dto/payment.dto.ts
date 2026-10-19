import { ApiProperty } from '@nestjs/swagger';
import { Transform } from 'class-transformer';
import { IsEnum, IsString, Length, Matches } from 'class-validator';
import { PaymentMethod } from '../../store-settings/dto/store-settings.dto.js';

export class SubmitPaymentDto {
  @ApiProperty({ enum: PaymentMethod })
  @IsEnum(PaymentMethod)
  method: PaymentMethod;
  @ApiProperty({
    example: 'OPERACION-123456',
    description: 'Referencia obligatoria; no prueba recepción de fondos.',
  })
  @Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? value.trim().toUpperCase() : value,
  )
  @Matches(/^[A-Z0-9][A-Z0-9_-]{3,79}$/)
  reference: string;
}
export class RejectPaymentDto {
  @ApiProperty({ example: 'No se encontró el ingreso de fondos.' })
  @Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? value.trim() : value,
  )
  @IsString()
  @Length(3, 500)
  reason: string;
}
