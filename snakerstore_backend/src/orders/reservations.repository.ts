import {
  ConflictException,
  Inject,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import type { Firestore } from 'firebase-admin/firestore';
import { FIREBASE_FIRESTORE } from '../firebase/firebase.providers.js';
import {
  expired,
  orderView,
  requireOpen,
  settleInventory,
} from './order-state.js';

@Injectable()
export class ReservationsRepository {
  constructor(
    @Inject(FIREBASE_FIRESTORE) private readonly firestore: Firestore,
  ) {}

  async expire(id: string) {
    const ref = this.firestore.collection('orders').doc(id);
    return this.firestore.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(ref);
      if (!snapshot.exists) return false;
      const order = snapshot.data()!;
      if (order.reservationState !== 'ACTIVE' || !expired(order)) return false;
      requireOpen(order);
      const paymentRef = order.currentPaymentId
        ? this.firestore.collection('payments').doc(order.currentPaymentId)
        : null;
      const payment = paymentRef ? await transaction.get(paymentRef) : null;
      const inventory = order.items.map(
        (item: { productId: string; size: string }) =>
          this.firestore
            .collection('inventory')
            .doc(`${item.productId}_${item.size}`),
      );
      const movements = inventory.map(() =>
        this.firestore.collection('inventory_movements').doc(),
      );
      await settleInventory(
        transaction,
        { ...order, id },
        inventory,
        movements,
        'SYSTEM',
        true,
      );
      transaction.update(ref, {
        status: 'CANCELADO',
        paymentStatus: 'VENCIDO',
        reservationState: 'RELEASED',
        reservationDueAt: FieldValue.delete(),
        cancellationReason: 'RESERVA_VENCIDA',
        updatedAt: FieldValue.serverTimestamp(),
        cancelledAt: FieldValue.serverTimestamp(),
        cancelledBy: 'SYSTEM',
      });
      if (
        paymentRef &&
        payment?.exists &&
        payment.data()!.status === 'PENDIENTE_VERIFICACION'
      )
        transaction.update(paymentRef, {
          status: 'CANCELADO',
          cancellationReason: 'RESERVA_VENCIDA',
          updatedAt: FieldValue.serverTimestamp(),
        });
      return true;
    });
  }

  async expireDue() {
    let expiredCount = 0;
    let failedCount = 0;
    let after;
    // Acotado por ejecución y con cursor: un documento inconsistente no bloquea a los siguientes.
    for (let page = 0; page < 10; page++) {
      let query = this.firestore
        .collection('orders')
        .where('reservationDueAt', '<=', Timestamp.now())
        .orderBy('reservationDueAt')
        .limit(100);
      if (after) query = query.startAfter(after);
      const snapshot = await query.get();
      if (snapshot.empty) break;
      for (const doc of snapshot.docs) {
        try {
          if (await this.expire(doc.id)) expiredCount++;
        } catch {
          failedCount++;
        }
      }
      after = snapshot.docs.at(-1);
      if (snapshot.size < 100) break;
    }
    return { expiredCount, failedCount };
  }

  async approve(paymentId: string, actorId: string) {
    const paymentRef = this.firestore.collection('payments').doc(paymentId);
    const paymentSnapshot = await paymentRef.get();
    if (!paymentSnapshot.exists)
      throw new NotFoundException('Pago no encontrado.');
    const orderRef = this.firestore
      .collection('orders')
      .doc(paymentSnapshot.data()!.orderId);
    return this.firestore.runTransaction(async (transaction) => {
      const [payment, snapshot] = await transaction.getAll(
        paymentRef,
        orderRef,
      );
      if (!payment.exists || !snapshot.exists)
        throw new NotFoundException('Pago o pedido no encontrado.');
      const data = payment.data()!;
      const order = snapshot.data()!;
      if (
        data.status === 'APROBADO' &&
        order.paymentStatus === 'APROBADO' &&
        order.currentPaymentId === paymentId
      )
        return orderView(snapshot.id, order);
      requireOpen(order);
      if (expired(order))
        throw new ConflictException(
          'La reserva venció; no se puede aprobar el pago.',
        );
      if (
        data.status !== 'PENDIENTE_VERIFICACION' ||
        order.currentPaymentId !== paymentId ||
        order.status !== 'PENDIENTE_VERIFICACION'
      )
        throw new ConflictException('El pago no está pendiente de revisión.');
      const inventory = order.items.map(
        (item: { productId: string; size: string }) =>
          this.firestore
            .collection('inventory')
            .doc(`${item.productId}_${item.size}`),
      );
      await settleInventory(
        transaction,
        { ...order, id: snapshot.id },
        inventory,
        inventory.map(() =>
          this.firestore.collection('inventory_movements').doc(),
        ),
        actorId,
        false,
      );
      if (expired(order))
        throw new ConflictException('La reserva venció durante la aprobación.');
      const changes = {
        status: 'PAGO_APROBADO',
        paymentStatus: 'APROBADO',
        reservationState: 'CONSUMED',
        reservationDueAt: FieldValue.delete(),
        fulfillmentStatus: 'PREPARANDO',
        approvedAt: FieldValue.serverTimestamp(),
        approvedBy: actorId,
        updatedAt: FieldValue.serverTimestamp(),
      };
      transaction.update(orderRef, changes);
      transaction.update(paymentRef, {
        status: 'APROBADO',
        reviewedAt: FieldValue.serverTimestamp(),
        reviewedBy: actorId,
        updatedAt: FieldValue.serverTimestamp(),
      });
      return orderView(snapshot.id, { ...order, ...changes });
    });
  }
}
