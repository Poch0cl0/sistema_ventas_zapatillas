import { BadRequestException, Inject, Injectable } from '@nestjs/common';
import { OrdersRepository } from './orders.repository.js';
import { DeliveryType } from './dto/order.dto.js';
import type {
  CreateOrderDto,
  FulfillmentStatus,
  OrderItemDto,
} from './dto/order.dto.js';
import type { OrderQueryDto } from './dto/order-query.dto.js';

@Injectable()
export class OrdersService {
  constructor(
    @Inject(OrdersRepository) private readonly repository: OrdersRepository,
  ) {}

  create(input: CreateOrderDto, uid: string, key: string | undefined) {
    if (!key || !/^[A-Za-z0-9_-]{8,128}$/.test(key))
      throw new BadRequestException(
        'Envía Idempotency-Key de 8–128 caracteres (letras, números, guiones).',
      );
    if (
      input.delivery.type === DeliveryType.PICKUP &&
      (input.delivery.zoneId !== undefined ||
        input.delivery.clientLat !== undefined ||
        input.delivery.clientLon !== undefined ||
        input.delivery.address !== undefined ||
        input.delivery.reference !== undefined)
    )
      throw new BadRequestException(
        'PICKUP no admite zona ni dirección de delivery.',
      );
    const variants = new Map<string, OrderItemDto>();
    for (const item of input.items) {
      const variant = `${item.productId}_${item.size}`;
      const quantity = (variants.get(variant)?.quantity ?? 0) + item.quantity;
      if (quantity > 100)
        throw new BadRequestException(
          'Máximo 100 unidades por producto y talla.',
        );
      variants.set(variant, {
        productId: item.productId,
        size: item.size,
        quantity,
      });
    }
    const items = [...variants.values()].sort((a, b) =>
      `${a.productId}_${a.size}`.localeCompare(`${b.productId}_${b.size}`),
    );
    const delivery = {
      type: input.delivery.type,
      recipientName: input.delivery.recipientName,
      phone: input.delivery.phone,
      ...(input.delivery.type === DeliveryType.DELIVERY
        ? {
            zoneId: input.delivery.zoneId,
            address:
              input.delivery.address ??
              `Punto de entrega: ${input.delivery.clientLat}, ${input.delivery.clientLon}`,
            ...(input.delivery.clientLat !== undefined &&
            input.delivery.clientLon !== undefined
              ? {
                  clientLat: input.delivery.clientLat,
                  clientLon: input.delivery.clientLon,
                }
              : {}),
            reference: input.delivery.reference ?? undefined,
          }
        : {}),
    };
    return this.repository.create({ items, delivery }, uid, key);
  }
  list(pagination: OrderQueryDto, uid?: string) {
    return this.repository.list(pagination, uid);
  }
  find(id: string, uid?: string) {
    return this.repository.find(id, uid);
  }
  cancel(id: string, uid: string) {
    return this.repository.cancel(id, uid);
  }
  fulfillment(id: string, status: FulfillmentStatus, actor: string) {
    return this.repository.fulfillment(id, status, actor);
  }
}
