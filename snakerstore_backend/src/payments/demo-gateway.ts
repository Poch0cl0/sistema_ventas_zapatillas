import {
  Body,
  Controller,
  Get,
  Post,
  Param,
  Inject,
  Injectable,
  ForbiddenException,
  NotFoundException,
  ConflictException,
  Header,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiOperation,
  ApiProperty,
  ApiTags,
} from '@nestjs/swagger';
import { IsIn } from 'class-validator';
import { ConfigService } from '@nestjs/config';
import {
  FieldValue,
  Timestamp,
  type Firestore,
} from 'firebase-admin/firestore';
import { FIREBASE_FIRESTORE } from '../firebase/firebase.providers.js';
import { CurrentUser, Roles } from '../common/decorators/auth.decorators.js';
import type { UserProfile } from '../common/auth.types.js';
import { DocumentIdDto } from '../common/dto/pagination.dto.js';
import { hash } from '../orders/orders.repository.js';
import type { DocumentData } from 'firebase-admin/firestore';
import {
  expired,
  requireOpen,
  settleInventory,
} from '../orders/order-state.js';

export function demoGatewayEnabled(config: ConfigService) {
  return (
    config.get('DEMO_GATEWAY_ENABLED') === 'true' ||
    (config.get('NODE_ENV') !== 'production' &&
      config.get('DEMO_GATEWAY_ENABLED') !== 'false')
  );
}
const SCENARIOS = ['APPROVED', 'REJECTED', 'PENDING'] as const;
export class DemoConfirmationDto {
  @ApiProperty({
    enum: SCENARIOS,
    description: 'Escenario de prueba; no enviar datos de tarjetas.',
  })
  @IsIn(SCENARIOS)
  scenario: (typeof SCENARIOS)[number];
}

@Injectable()
export class DemoGatewayService {
  constructor(
    @Inject(FIREBASE_FIRESTORE) private readonly firestore: Firestore,
    @Inject(ConfigService) private readonly config: ConfigService,
  ) {}
  private enabled() {
    if (!demoGatewayEnabled(this.config))
      throw new ForbiddenException('La pasarela demo está deshabilitada.');
  }
  async checkout(orderId: string, uid: string) {
    this.enabled();
    const orderRef = this.firestore.collection('orders').doc(orderId);
    const id = hash(`demo:${uid}:${orderId}`);
    const ref = this.firestore.collection('demo_checkouts').doc(id);
    return this.firestore.runTransaction(async (transaction) => {
      const [snapshot, session] = await transaction.getAll(orderRef, ref);
      if (!snapshot.exists || snapshot.data()!.userId !== uid)
        throw new NotFoundException('Pedido no encontrado.');
      const order = snapshot.data()!;
      if (session.exists && session.data()!.status === 'APPROVED')
        return this.view(id, session.data()!);
      requireOpen(order);
      if (expired(order))
        throw new ConflictException('La reserva venció. Crea un pedido nuevo.');
      if (order.currentPaymentId)
        throw new ConflictException(
          'El pedido ya tiene un pago manual en revisión.',
        );
      if (session.exists) return this.view(id, session.data()!);
      const data = {
        orderId,
        userId: uid,
        amountCents: order.totalCents,
        currency: 'PEN',
        status: 'CREATED',
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
      };
      transaction.create(ref, data);
      // Entering this checkout explicitly converts the order to a demo order.
      transaction.update(orderRef, {
        isSimulation: true,
        updatedAt: Timestamp.now(),
      });
      return this.view(id, data);
    });
  }
  async find(id: string, uid: string) {
    this.enabled();
    const snapshot = await this.firestore
      .collection('demo_checkouts')
      .doc(id)
      .get();
    if (!snapshot.exists || snapshot.data()!.userId !== uid)
      throw new NotFoundException('Checkout no encontrado.');
    return this.view(id, snapshot.data()!);
  }
  async confirm(
    id: string,
    scenario: DemoConfirmationDto['scenario'],
    uid: string,
  ) {
    this.enabled();
    const ref = this.firestore.collection('demo_checkouts').doc(id);
    return this.firestore.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(ref);
      if (!snapshot.exists || snapshot.data()!.userId !== uid)
        throw new NotFoundException('Checkout no encontrado.');
      const session = snapshot.data()!;
      if (session.status === 'APPROVED') return this.view(id, session);
      const orderRef = this.firestore.collection('orders').doc(session.orderId);
      const orderSnapshot = await transaction.get(orderRef);
      if (!orderSnapshot.exists || orderSnapshot.data()!.userId !== uid)
        throw new NotFoundException('Pedido no encontrado.');
      const order = orderSnapshot.data()!;
      requireOpen(order);
      if (expired(order)) throw new ConflictException('La reserva venció.');
      if (order.currentPaymentId || order.totalCents !== session.amountCents)
        throw new ConflictException(
          'El pedido cambió o tiene un pago manual en revisión.',
        );
      if (scenario === 'APPROVED') {
        const refs = order.items.map(
          (item: { productId: string; size: string }) =>
            this.firestore
              .collection('inventory')
              .doc(`${item.productId}_${item.size}`),
        );
        await settleInventory(
          transaction,
          { ...order, id: session.orderId },
          refs,
          refs.map(() =>
            this.firestore.collection('inventory_movements').doc(),
          ),
          uid,
          false,
          'PAY',
        );
        if (expired(order))
          throw new ConflictException(
            'La reserva venció durante la aprobación demo.',
          );
        transaction.update(orderRef, {
          isSimulation: true,
          status: 'PAGO_SIMULADO',
          paymentStatus: 'SIMULADO',
          fulfillmentStatus: 'PREPARANDO',
          reservationState: 'CONSUMED',
          reservationDueAt: FieldValue.delete(),
          simulationCompletedAt: Timestamp.now(),
          updatedAt: Timestamp.now(),
        });
      } else {
        transaction.update(orderRef, {
          isSimulation: true,
          status: scenario === 'REJECTED' ? 'PAGO_RECHAZADO' : 'PENDIENTE_PAGO',
          paymentStatus: scenario === 'REJECTED' ? 'RECHAZADO' : 'PENDIENTE',
          updatedAt: Timestamp.now(),
        });
      }
      const changes = { status: scenario, updatedAt: Timestamp.now() };
      transaction.update(ref, changes);
      return this.view(id, { ...session, ...changes });
    });
  }
  private view(id: string, data: DocumentData) {
    return {
      id,
      orderId: data.orderId,
      amountCents: data.amountCents,
      currency: 'PEN',
      status: data.status,
      provider: 'LOCAL_DEMO',
      testMode: true,
      scenarios: SCENARIOS,
    };
  }
}

@ApiTags('Pasarela de pruebas sin claves')
@ApiBearerAuth()
@Roles('CLIENTE')
@Controller()
export class DemoGatewayController {
  constructor(
    @Inject(DemoGatewayService) private readonly gateway: DemoGatewayService,
  ) {}
  @Post('orders/:id/demo-checkout')
  @ApiOperation({
    summary:
      'Crear checkout demo con importe del servidor; convierte el pedido a simulación.',
  })
  checkout(@Param() params: DocumentIdDto, @CurrentUser() user: UserProfile) {
    return this.gateway.checkout(params.id, user.uid);
  }
  @Get('demo-checkouts/:id')
  @Header('Cache-Control', 'no-store')
  find(@Param() params: DocumentIdDto, @CurrentUser() user: UserProfile) {
    return this.gateway.find(params.id, user.uid);
  }
  @Post('demo-checkouts/:id/confirm')
  confirm(
    @Param() params: DocumentIdDto,
    @Body() input: DemoConfirmationDto,
    @CurrentUser() user: UserProfile,
  ) {
    return this.gateway.confirm(params.id, input.scenario, user.uid);
  }
}
