import { BadRequestException, Inject, Injectable } from '@nestjs/common';
import { DeliveryZonesRepository } from './delivery-zones.repository.js';
import type { PaginationDto } from '../common/dto/pagination.dto.js';
import type {
  CreateDeliveryZoneDto,
  UpdateDeliveryZoneDto,
} from './dto/delivery-zone.dto.js';

@Injectable()
export class DeliveryZonesService {
  constructor(
    @Inject(DeliveryZonesRepository)
    private readonly repository: DeliveryZonesRepository,
  ) {}
  list(pagination: PaginationDto, onlyActive: boolean) {
    return this.repository.list(pagination, onlyActive);
  }
  create(input: CreateDeliveryZoneDto, actorId: string) {
    return this.repository.create(input, actorId);
  }
  update(id: string, input: UpdateDeliveryZoneDto, actorId: string) {
    if (!Object.keys(input).length)
      throw new BadRequestException('Envía al menos un campo para actualizar.');
    return this.repository.update(id, input, actorId);
  }
}
