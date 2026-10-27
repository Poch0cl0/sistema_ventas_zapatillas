import {
  Body,
  Controller,
  Get,
  Header,
  Inject,
  Param,
  Post,
  ForbiddenException,
  StreamableFile,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { ConfigService } from '@nestjs/config';
import { IsEnum } from 'class-validator';
import {
  CurrentUser,
  Public,
  Roles,
} from '../common/decorators/auth.decorators.js';
import type { UserProfile } from '../common/auth.types.js';
import { DocumentIdDto } from '../common/dto/pagination.dto.js';
import { OrdersRepository } from './orders.repository.js';
import { demoGatewayEnabled } from '../payments/demo-gateway.js';
import { ReceiptsService } from '../receipts/receipts.service.js';

enum SimulationAction {
  PAY = 'PAY',
  SKIP = 'SKIP',
}
class SimulationDto {
  @IsEnum(SimulationAction)
  action: SimulationAction;
}

@ApiTags('Opciones de compra')
@Controller('checkout-options')
export class CheckoutOptionsController {
  constructor(@Inject(ConfigService) private readonly config: ConfigService) {}
  @Public()
  @Get()
  @Header('Cache-Control', 'no-store')
  get() {
    return {
      simulationEnabled:
        this.config.get<string>('CHECKOUT_SIMULATION_ENABLED') === 'true',
      demoGatewayEnabled: demoGatewayEnabled(this.config),
    };
  }
}

@ApiTags('Simulación y boletas')
@ApiBearerAuth()
@Controller('orders')
export class SimulationController {
  constructor(
    @Inject(ConfigService) private readonly config: ConfigService,
    @Inject(OrdersRepository) private readonly orders: OrdersRepository,
    @Inject(ReceiptsService) private readonly receipts: ReceiptsService,
  ) {}

  @Post(':id/simulation')
  @Roles('CLIENTE')
  @ApiOperation({
    summary: 'Continuar sin pago o simular un pago; nunca registra dinero real',
  })
  async complete(
    @Param() params: DocumentIdDto,
    @Body() input: SimulationDto,
    @CurrentUser() user: UserProfile,
  ) {
    if (this.config.get<string>('CHECKOUT_SIMULATION_ENABLED') !== 'true')
      throw new ForbiddenException('La tienda no habilitó la simulación.');
    const order = await this.orders.completeSimulation(
      params.id,
      user.uid,
      input.action,
    );
    const receipt =
      input.action === SimulationAction.PAY
        ? await this.receipts.deliver(params.id, user.uid)
        : null;
    return { ...order, receiptStatus: receipt?.status ?? order.receiptStatus };
  }

  @Get(':id/receipt')
  @Header('Cache-Control', 'no-store')
  get(@Param() params: DocumentIdDto, @CurrentUser() user: UserProfile) {
    return this.receipts.get(
      params.id,
      user.role === 'ADMINISTRADOR' ? undefined : user.uid,
    );
  }

  @Get(':id/receipt/pdf')
  @Header('Cache-Control', 'no-store')
  async pdf(@Param() params: DocumentIdDto, @CurrentUser() user: UserProfile) {
    const file = await this.receipts.pdf(
      params.id,
      user.role === 'ADMINISTRADOR' ? undefined : user.uid,
    );
    return new StreamableFile(file, {
      type: 'application/pdf',
      disposition: `attachment; filename="Boleta-simulacion-${params.id.slice(0, 12)}.pdf"`,
    });
  }

  @Post(':id/receipt/send')
  @Roles('CLIENTE')
  async send(@Param() params: DocumentIdDto, @CurrentUser() user: UserProfile) {
    await this.receipts.get(params.id, user.uid);
    return this.receipts.deliver(params.id, user.uid);
  }
}
