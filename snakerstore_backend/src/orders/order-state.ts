import { ConflictException } from '@nestjs/common';
import { Timestamp, FieldValue } from 'firebase-admin/firestore';
import type {
  DocumentData,
  DocumentReference,
  Transaction,
} from 'firebase-admin/firestore';

export const RESERVATION_MS = 24 * 60 * 60 * 1000;
export const OPEN_STATUSES = [
  'PENDIENTE_PAGO',
  'PENDIENTE_VERIFICACION',
  'PAGO_RECHAZADO',
];

export function expired(order: DocumentData, now = Date.now()) {
  return (
    order.reservationExpiresAt instanceof Timestamp &&
    order.reservationExpiresAt.toMillis() <= now
  );
}

export function requireOpen(order: DocumentData) {
  if (
    order.reservationState !== 'ACTIVE' ||
    !OPEN_STATUSES.includes(order.status)
  )
    throw new ConflictException('El pedido ya no tiene una reserva activa.');
}

export async function settleInventory(
  transaction: Transaction,
  order: DocumentData,
  inventoryRefs: DocumentReference[],
  movementRefs: DocumentReference[],
  actorId: string,
  release: boolean,
  simulationAction?: 'PAY' | 'SKIP',
) {
  const snapshots = await transaction.getAll(...inventoryRefs);
  const changes = snapshots.map((snapshot, index) => {
    const data = snapshot.data();
    const quantity = order.items[index].quantity;
    if (
      !data ||
      !Number.isSafeInteger(data.available) ||
      !Number.isSafeInteger(data.reserved) ||
      data.available < 0 ||
      data.reserved < quantity
    )
      throw new ConflictException('El inventario reservado requiere revisión.');
    return {
      available: data.available + (release ? quantity : 0),
      reserved: data.reserved - quantity,
      before: data.available,
      beforeReserved: data.reserved,
    };
  });
  changes.forEach((change, index) => {
    transaction.update(inventoryRefs[index], {
      available: change.available,
      reserved: change.reserved,
      updatedAt: FieldValue.serverTimestamp(),
    });
    const item = order.items[index];
    transaction.create(movementRefs[index], {
      inventoryId: inventoryRefs[index].id,
      productId: item.productId,
      size: item.size,
      orderId: order.id,
      type: release
        ? 'LIBERACION_RESERVA'
        : simulationAction === 'PAY'
          ? 'VENTA_SIMULADA'
          : simulationAction === 'SKIP'
            ? 'PEDIDO_SIN_PAGO'
            : 'VENTA_PEDIDO',
      delta: release ? item.quantity : 0,
      reservedDelta: -item.quantity,
      availableBefore: change.before,
      availableAfter: change.available,
      reservedBefore: change.beforeReserved,
      reservedAfter: change.reserved,
      actorId,
      reason: release
        ? 'Cancelación o vencimiento del pedido online'
        : simulationAction
          ? 'Pedido de simulación sin cobro real'
          : 'Pago del pedido online aprobado',
      createdAt: FieldValue.serverTimestamp(),
    });
  });
}

export function orderView(id: string, data: DocumentData) {
  const iso = (value: unknown) =>
    value instanceof Timestamp ? value.toDate().toISOString() : null;
  return {
    id,
    userId: data.userId,
    items: data.items,
    subtotalCents: data.subtotalCents,
    deliveryFeeCents: data.deliveryFeeCents,
    totalCents: data.totalCents,
    currency: 'PEN',
    delivery: data.delivery,
    status: data.status,
    paymentStatus: data.paymentStatus,
    fulfillmentStatus: data.fulfillmentStatus,
    reservationState: data.reservationState,
    reservationExpiresAt: iso(data.reservationExpiresAt),
    createdAt: iso(data.createdAt),
    currentPaymentId: data.currentPaymentId ?? null,
    cancellationReason: data.cancellationReason ?? null,
    isSimulation: data.isSimulation === true,
    simulationCompletedAt: iso(data.simulationCompletedAt),
    receiptStatus: data.receiptStatus ?? null,
  };
}

export function paymentView(id: string, data: DocumentData) {
  return {
    id,
    orderId: data.orderId,
    method: data.method,
    reference: data.reference,
    status: data.status,
    amountCents: data.amountCents,
    rejectionReason: data.rejectionReason ?? null,
    createdAt:
      data.createdAt instanceof Timestamp
        ? data.createdAt.toDate().toISOString()
        : null,
    reviewedAt:
      data.reviewedAt instanceof Timestamp
        ? data.reviewedAt.toDate().toISOString()
        : null,
  };
}
