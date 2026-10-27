import { ApiProperty } from '@nestjs/swagger';

class OrderItemResponseDto {
  @ApiProperty({ type: String }) productId: string;
  @ApiProperty({ type: String }) name: string;
  @ApiProperty({ type: String }) size: string;
  @ApiProperty({ type: Number }) quantity: number;
  @ApiProperty({ type: Number }) unitPriceCents: number;
}

export class OrderResponseDto {
  @ApiProperty({ type: Boolean }) isSimulation: boolean;
  @ApiProperty({ type: String, nullable: true }) receiptStatus: string | null;
  @ApiProperty({ type: String, format: 'date-time', nullable: true })
  simulationCompletedAt: string | null;
  @ApiProperty({ type: String }) id: string;
  @ApiProperty({ type: String }) userId: string;
  @ApiProperty({ type: [OrderItemResponseDto] }) items: OrderItemResponseDto[];
  @ApiProperty({ type: Number }) subtotalCents: number;
  @ApiProperty({ type: Number }) deliveryFeeCents: number;
  @ApiProperty({ type: Number }) totalCents: number;
  @ApiProperty({ enum: ['PEN'] }) currency: string;
  @ApiProperty({
    type: 'object',
    additionalProperties: true,
    description:
      'Snapshot de entrega: type, recipientName y phone; DELIVERY añade zona, dirección, referencia, tarifa y clientLat/clientLon cuando se eligió un pin; PICKUP añade dirección, instrucciones y horario de tienda.',
  })
  delivery: Record<string, unknown>;
  @ApiProperty({
    enum: [
      'PENDIENTE_PAGO',
      'PENDIENTE_VERIFICACION',
      'PAGO_RECHAZADO',
      'PAGO_APROBADO',
      'PAGO_SIMULADO',
      'CONFIRMADO_SIN_PAGO',
      'CANCELADO',
    ],
  })
  status: string;
  @ApiProperty({
    enum: [
      'PENDIENTE',
      'PENDIENTE_VERIFICACION',
      'RECHAZADO',
      'APROBADO',
      'SIMULADO',
      'NO_REQUERIDO',
      'VENCIDO',
      'CANCELADO',
    ],
  })
  paymentStatus: string;
  @ApiProperty({
    enum: [
      'SIN_INICIAR',
      'PREPARANDO',
      'LISTO_RECOJO',
      'EN_REPARTO',
      'ENTREGADO',
    ],
  })
  fulfillmentStatus: string;
  @ApiProperty({ enum: ['ACTIVE', 'CONSUMED', 'RELEASED'] })
  reservationState: string;
  @ApiProperty({ type: String, format: 'date-time', nullable: true })
  reservationExpiresAt: string | null;
  @ApiProperty({ type: String, format: 'date-time', nullable: true })
  createdAt: string | null;
  @ApiProperty({ type: String, format: 'date-time', nullable: true })
  approvedAt: string | null;
  @ApiProperty({ type: String, nullable: true }) currentPaymentId:
    string | null;
  @ApiProperty({ type: String, nullable: true }) cancellationReason:
    string | null;
}
export class OrderPageDto {
  @ApiProperty({ type: [OrderResponseDto] }) items: OrderResponseDto[];
  @ApiProperty({ type: String, nullable: true }) nextCursor: string | null;
}
export class PaymentResponseDto {
  @ApiProperty({ type: String }) id: string;
  @ApiProperty({ type: String }) orderId: string;
  @ApiProperty({ enum: ['YAPE', 'PLIN', 'TRANSFERENCIA'] }) method: string;
  @ApiProperty({ type: String }) reference: string;
  @ApiProperty({
    enum: ['PENDIENTE_VERIFICACION', 'RECHAZADO', 'APROBADO', 'CANCELADO'],
  })
  status: string;
  @ApiProperty({ type: Number }) amountCents: number;
  @ApiProperty({ type: String, nullable: true }) rejectionReason: string | null;
  @ApiProperty({ type: String, format: 'date-time', nullable: true })
  createdAt: string | null;
  @ApiProperty({ type: String, format: 'date-time', nullable: true })
  reviewedAt: string | null;
}
export class PaymentPageDto {
  @ApiProperty({ type: [PaymentResponseDto] }) items: PaymentResponseDto[];
  @ApiProperty({ type: String, nullable: true }) nextCursor: string | null;
}
export class ExpirationResponseDto {
  @ApiProperty({ type: Number }) expiredCount: number;
  @ApiProperty({ type: Number }) failedCount: number;
}
