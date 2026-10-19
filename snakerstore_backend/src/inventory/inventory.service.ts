import { Inject, Injectable } from '@nestjs/common';
import { InventoryRepository } from './inventory.repository.js';
import type {
  AdjustInventoryDto,
  CreateInventoryDto,
  InventoryQueryDto,
  MovementQueryDto,
} from './dto/inventory.dto.js';

@Injectable()
export class InventoryService {
  constructor(
    @Inject(InventoryRepository)
    private readonly repository: InventoryRepository,
  ) {}
  list(query: InventoryQueryDto) {
    return this.repository.list(query);
  }
  movements(query: MovementQueryDto) {
    return this.repository.movements(query);
  }
  create(input: CreateInventoryDto, uid: string) {
    return this.repository.create(input, uid);
  }
  adjust(id: string, input: AdjustInventoryDto, uid: string) {
    return this.repository.adjust(id, input, uid);
  }
}
