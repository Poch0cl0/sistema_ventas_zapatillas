import {
  Body,
  Controller,
  Get,
  Header,
  Inject,
  Param,
  Post,
  Query,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiConflictResponse,
  ApiForbiddenResponse,
  ApiNotFoundResponse,
  ApiOperation,
  ApiTags,
  ApiUnauthorizedResponse,
} from '@nestjs/swagger';
import { CurrentUser, Roles } from '../common/decorators/auth.decorators.js';
import type { UserProfile } from '../common/auth.types.js';
import { DocumentIdDto, PaginationDto } from '../common/dto/pagination.dto.js';
import { RejectPaymentDto, SubmitPaymentDto } from './dto/payment.dto.js';
import { PaymentsRepository } from './payments.repository.js';
import { ReservationsRepository } from '../orders/reservations.repository.js';
import { ApiCreatedResponse, ApiOkResponse } from '@nestjs/swagger';
import {
  OrderResponseDto,
  PaymentPageDto,
  PaymentResponseDto,
} from '../orders/dto/order-response.dto.js';

@ApiTags('Pagos del pedido')
@ApiBearerAuth()
@ApiUnauthorizedResponse({ description: 'Sesión requerida.' })
@ApiNotFoundResponse({ description: 'Pedido inexistente o ajeno.' })
@ApiConflictResponse({
  description:
    'Reserva vencida, referencia duplicada o pago pendiente de revisión.',
})
@Controller('orders/:id/payments')
export class PaymentsController {
  constructor(
    @Inject(PaymentsRepository) private readonly payments: PaymentsRepository,
  ) {}
  @Post()
  @ApiCreatedResponse({ type: PaymentResponseDto })
  @Roles('CLIENTE')
  @ApiOperation({
    summary:
      'Enviar referencia de pago (JSON); no equivale a pago aprobado; sin imagen de comprobante en esta fase',
  })
  submit(
    @Param() params: DocumentIdDto,
    @Body() input: SubmitPaymentDto,
    @CurrentUser() user: UserProfile,
  ) {
    return this.payments.submit(params.id, input, user.uid);
  }
  @Get()
  @ApiOkResponse({ type: PaymentPageDto })
  @Header('Cache-Control', 'no-store')
  @ApiOperation({
    summary:
      'Consultar intentos de pago del pedido propio o como administrador',
  })
  list(
    @Param() params: DocumentIdDto,
    @Query() pagination: PaginationDto,
    @CurrentUser() user: UserProfile,
  ) {
    return this.payments.list(
      params.id,
      pagination,
      user.role === 'ADMINISTRADOR' ? undefined : user.uid,
    );
  }
}

@ApiTags('Verificación administrativa de pagos')
@ApiBearerAuth()
@Roles('ADMINISTRADOR')
@ApiUnauthorizedResponse({ description: 'Sesión requerida.' })
@ApiForbiddenResponse({ description: 'Solo ADMINISTRADOR.' })
@ApiConflictResponse({
  description: 'Pago no revisable, reserva vencida o inventario inconsistente.',
})
@Controller('admin/payments')
export class AdminPaymentsController {
  constructor(
    @Inject(PaymentsRepository) private readonly payments: PaymentsRepository,
    @Inject(ReservationsRepository)
    private readonly reservations: ReservationsRepository,
  ) {}
  @Post(':id/approve')
  @ApiCreatedResponse({ type: OrderResponseDto })
  @ApiOperation({
    summary:
      'Aprobar tras verificar fondos recibidos; consolida la venta sin reducir available otra vez',
  })
  approve(@Param() params: DocumentIdDto, @CurrentUser() user: UserProfile) {
    return this.reservations.approve(params.id, user.uid);
  }
  @Post(':id/reject')
  @ApiCreatedResponse({ type: PaymentResponseDto })
  @ApiOperation({
    summary:
      'Rechazar con motivo; permite otra referencia dentro de las 24 horas originales',
  })
  reject(
    @Param() params: DocumentIdDto,
    @Body() input: RejectPaymentDto,
    @CurrentUser() user: UserProfile,
  ) {
    return this.payments.reject(params.id, input.reason, user.uid);
  }
}
