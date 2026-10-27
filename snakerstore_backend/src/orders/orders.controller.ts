import {
  Body,
  Controller,
  Get,
  Header,
  Headers,
  Inject,
  Param,
  Patch,
  Post,
  Query,
} from '@nestjs/common';
import {
  ApiBadRequestResponse,
  ApiBearerAuth,
  ApiConflictResponse,
  ApiForbiddenResponse,
  ApiHeader,
  ApiNotFoundResponse,
  ApiOperation,
  ApiTags,
  ApiUnauthorizedResponse,
} from '@nestjs/swagger';
import { CurrentUser, Roles } from '../common/decorators/auth.decorators.js';
import type { UserProfile } from '../common/auth.types.js';
import { DocumentIdDto, PaginationDto } from '../common/dto/pagination.dto.js';
import { CreateOrderDto, FulfillmentDto } from './dto/order.dto.js';
import { OrdersService } from './orders.service.js';
import { OrderQueryDto } from './dto/order-query.dto.js';
import { ReservationsRepository } from './reservations.repository.js';
import { ApiCreatedResponse, ApiOkResponse } from '@nestjs/swagger';
import {
  ExpirationResponseDto,
  OrderPageDto,
  OrderResponseDto,
} from './dto/order-response.dto.js';

@ApiTags('Pedidos del cliente')
@ApiBearerAuth()
@ApiUnauthorizedResponse({ description: 'Sesión requerida o inválida.' })
@ApiForbiddenResponse({ description: 'Permisos insuficientes.' })
@ApiBadRequestResponse({
  description: 'Datos o clave de idempotencia inválidos.',
})
@ApiConflictResponse({
  description:
    'Stock insuficiente, reserva cerrada o clave reutilizada con otros datos.',
})
@ApiNotFoundResponse({ description: 'Pedido inexistente o ajeno.' })
@Controller('orders')
export class OrdersController {
  constructor(@Inject(OrdersService) private readonly orders: OrdersService) {}
  @Post()
  @ApiCreatedResponse({ type: OrderResponseDto })
  @Roles('CLIENTE')
  @ApiHeader({
    name: 'Idempotency-Key',
    required: true,
    description:
      'Identificador único por checkout; reutilizar solo para reintentar el mismo pedido.',
    schema: { type: 'string', minLength: 8, maxLength: 128 },
    example: 'checkout-00000001',
  })
  @ApiOperation({
    summary:
      'Crear pedido y reservar stock durante 24 horas; totales calculados por el servidor',
  })
  create(
    @Body() input: CreateOrderDto,
    @CurrentUser() user: UserProfile,
    @Headers('idempotency-key') key?: string,
  ) {
    return this.orders.create(input, user.uid, key);
  }
  @Get()
  @ApiOkResponse({ type: OrderPageDto })
  @Roles('CLIENTE')
  @Header('Cache-Control', 'no-store')
  @ApiOperation({ summary: 'Listar solo mis pedidos' })
  list(@Query() pagination: PaginationDto, @CurrentUser() user: UserProfile) {
    return this.orders.list(pagination, user.uid);
  }
  @Get(':id')
  @ApiOkResponse({ type: OrderResponseDto })
  @Header('Cache-Control', 'no-store')
  @ApiOperation({
    summary: 'Consultar pedido propio o consultar como administrador',
  })
  find(@Param() params: DocumentIdDto, @CurrentUser() user: UserProfile) {
    return this.orders.find(
      params.id,
      user.role === 'ADMINISTRADOR' ? undefined : user.uid,
    );
  }
  @Post(':id/cancel')
  @ApiCreatedResponse({ type: OrderResponseDto })
  @Roles('CLIENTE')
  @ApiOperation({
    summary: 'Cancelar mi pedido antes de aprobarse el pago y liberar stock',
  })
  cancel(@Param() params: DocumentIdDto, @CurrentUser() user: UserProfile) {
    return this.orders.cancel(params.id, user.uid);
  }
}

@ApiTags('Administración de pedidos')
@ApiBearerAuth()
@Roles('ADMINISTRADOR')
@ApiUnauthorizedResponse({ description: 'Sesión requerida.' })
@ApiForbiddenResponse({ description: 'Solo ADMINISTRADOR.' })
@ApiConflictResponse({ description: 'Transición no permitida.' })
@Controller('admin/orders')
export class AdminOrdersController {
  constructor(
    @Inject(OrdersService) private readonly orders: OrdersService,
    @Inject(ReservationsRepository)
    private readonly reservations: ReservationsRepository,
  ) {}
  @Get()
  @ApiOkResponse({ type: OrderPageDto })
  @Header('Cache-Control', 'no-store')
  @ApiOperation({ summary: 'Listar todos los pedidos online' })
  list(@Query() pagination: OrderQueryDto) {
    return this.orders.list(pagination);
  }
  @Post('expire')
  @ApiCreatedResponse({ type: ExpirationResponseDto })
  @ApiOperation({
    summary:
      'Procesar reservas ya vencidas (no adelanta la fecha de vencimiento)',
  })
  expire() {
    return this.reservations.expireDue();
  }
  @Patch(':id/status')
  @ApiOkResponse({ type: OrderResponseDto })
  @ApiOperation({
    summary:
      'Avanzar preparación → listo para recojo/en reparto → entregado; admite pago aprobado o simulación confirmada con o sin pago',
  })
  status(
    @Param() params: DocumentIdDto,
    @Body() input: FulfillmentDto,
    @CurrentUser() user: UserProfile,
  ) {
    return this.orders.fulfillment(params.id, input.status, user.uid);
  }
}
