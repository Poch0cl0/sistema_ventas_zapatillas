import {
  ConflictException,
  Inject,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import type { Firestore } from 'firebase-admin/firestore';
import { FIREBASE_FIRESTORE } from '../firebase/firebase.providers.js';
import { expired, paymentView, requireOpen } from '../orders/order-state.js';
import { hash } from '../orders/orders.repository.js';
import { firestorePage } from '../common/firestore-page.js';
import type { PaginationDto } from '../common/dto/pagination.dto.js';
import type { SubmitPaymentDto } from './dto/payment.dto.js';

@Injectable()
export class PaymentsRepository {
  constructor(
    @Inject(FIREBASE_FIRESTORE) private readonly firestore: Firestore,
  ) {}

  async submit(orderId: string, input: SubmitPaymentDto, uid: string) {
    const paymentId = hash(`${input.method}:${input.reference}`);
    const paymentRef = this.firestore.collection('payments').doc(paymentId);
    const orderRef = this.firestore.collection('orders').doc(orderId);
    return this.firestore.runTransaction(async (transaction) => {
      const [snapshot, existing, settings] = await transaction.getAll(
        orderRef,
        paymentRef,
        this.firestore.collection('store_settings').doc('main'),
      );
      if (!snapshot.exists || snapshot.data()!.userId !== uid)
        throw new NotFoundException('Pedido no encontrado.');
      const order = snapshot.data()!;
      if (order.isSimulation === true)
        throw new ConflictException(
          'Este pedido es de simulación. Usa las opciones de pago simulado o continuar sin pago.',
        );
      if (existing.exists) {
        if (existing.data()!.orderId !== orderId)
          throw new ConflictException(
            'La referencia ya está registrada. Requiere revisión.',
          );
        return paymentView(paymentId, existing.data()!);
      }
      requireOpen(order);
      if (expired(order)) throw new ConflictException('La reserva venció.');
      if (order.status === 'PENDIENTE_VERIFICACION')
        throw new ConflictException('Ya hay un pago pendiente de revisión.');
      const methods = settings.data()?.paymentMethods;
      if (
        !Array.isArray(methods) ||
        !methods.some(
          (method) => method.method === input.method && method.enabled === true,
        )
      )
        throw new ConflictException('El método de pago no está habilitado.');
      const createdAt = Timestamp.now();
      const data = {
        orderId,
        userId: uid,
        method: input.method,
        reference: input.reference,
        amountCents: order.totalCents,
        status: 'PENDIENTE_VERIFICACION',
        createdAt,
        updatedAt: createdAt,
      };
      transaction.create(paymentRef, data);
      transaction.update(orderRef, {
        status: 'PENDIENTE_VERIFICACION',
        paymentStatus: 'PENDIENTE_VERIFICACION',
        currentPaymentId: paymentId,
        updatedAt: createdAt,
      });
      return paymentView(paymentId, data);
    });
  }

  async reject(id: string, reason: string, actorId: string) {
    const ref = this.firestore.collection('payments').doc(id);
    return this.firestore.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(ref);
      if (!snapshot.exists) throw new NotFoundException('Pago no encontrado.');
      const payment = snapshot.data()!;
      const orderRef = this.firestore.collection('orders').doc(payment.orderId);
      const orderSnapshot = await transaction.get(orderRef);
      if (!orderSnapshot.exists)
        throw new NotFoundException('Pedido no encontrado.');
      const order = orderSnapshot.data()!;
      if (payment.status === 'RECHAZADO') {
        if (payment.rejectionReason !== reason)
          throw new ConflictException(
            'El pago ya fue rechazado con otro motivo.',
          );
        return paymentView(id, payment);
      }
      requireOpen(order);
      if (expired(order)) throw new ConflictException('La reserva venció.');
      if (
        payment.status !== 'PENDIENTE_VERIFICACION' ||
        order.currentPaymentId !== id
      )
        throw new ConflictException('El pago no está pendiente de revisión.');
      const reviewedAt = Timestamp.now();
      const changes = {
        status: 'RECHAZADO',
        rejectionReason: reason,
        reviewedBy: actorId,
        reviewedAt,
        updatedAt: reviewedAt,
      };
      transaction.update(ref, changes);
      transaction.update(orderRef, {
        status: 'PAGO_RECHAZADO',
        paymentStatus: 'RECHAZADO',
        updatedAt: FieldValue.serverTimestamp(),
      });
      return paymentView(id, { ...payment, ...changes });
    });
  }

  async list(orderId: string, pagination: PaginationDto, uid?: string) {
    const order = await this.firestore.collection('orders').doc(orderId).get();
    if (!order.exists || (uid && order.data()!.userId !== uid))
      throw new NotFoundException('Pedido no encontrado.');
    const result = await firestorePage(
      this.firestore.collection('payments').where('orderId', '==', orderId),
      pagination,
    );
    return {
      items: result.docs.map((doc) => paymentView(doc.id, doc.data())),
      nextCursor: result.nextCursor,
    };
  }
}
