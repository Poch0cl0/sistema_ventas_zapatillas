import { Module } from '@nestjs/common';
import {
  DeliveryZonesController,
  AdminDeliveryZonesController,
} from './delivery-zones.controller.js';
import { DeliveryZonesRepository } from './delivery-zones.repository.js';
import { DeliveryZonesService } from './delivery-zones.service.js';

@Module({
  controllers: [DeliveryZonesController, AdminDeliveryZonesController],
  providers: [DeliveryZonesRepository, DeliveryZonesService],
})
export class DeliveryZonesModule {}
