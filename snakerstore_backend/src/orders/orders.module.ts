import { Module } from '@nestjs/common';
import { ReceiptsService } from '../receipts/receipts.service.js';
import {
  DemoGatewayController,
  DemoGatewayService,
} from '../payments/demo-gateway.js';
import {
  CheckoutOptionsController,
  SimulationController,
} from './simulation.controller.js';
import { OrdersRepository } from './orders.repository.js';
import { OrdersService } from './orders.service.js';
import { ReservationsRepository } from './reservations.repository.js';
import {
  OrdersController,
  AdminOrdersController,
} from './orders.controller.js';
import { PaymentsRepository } from '../payments/payments.repository.js';
import {
  PaymentsController,
  AdminPaymentsController,
} from '../payments/payments.controller.js';

@Module({
  controllers: [
    OrdersController,
    AdminOrdersController,
    PaymentsController,
    AdminPaymentsController,
    CheckoutOptionsController,
    SimulationController,
    DemoGatewayController,
  ],
  providers: [
    OrdersRepository,
    OrdersService,
    ReservationsRepository,
    PaymentsRepository,
    ReceiptsService,
    DemoGatewayService,
  ],
})
export class OrdersModule {}
