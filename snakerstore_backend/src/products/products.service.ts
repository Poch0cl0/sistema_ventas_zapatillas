import { BadRequestException, Inject, Injectable } from '@nestjs/common';
import { ProductsRepository } from './products.repository.js';
import type { CreateProductDto, UpdateProductDto } from './dto/product.dto.js';
import type { CatalogQueryDto } from './dto/catalog-query.dto.js';

@Injectable()
export class ProductsService {
  constructor(
    @Inject(ProductsRepository) private readonly repository: ProductsRepository,
  ) {}
  list(pagination: CatalogQueryDto, onlyActive = true) {
    return this.repository.list(pagination, onlyActive);
  }
  find(id: string, onlyActive = true) {
    return this.repository.find(id, onlyActive);
  }
  availability(id: string) {
    return this.repository.availability(id);
  }
  create(input: CreateProductDto, uid: string) {
    return this.repository.create(input, uid);
  }
  update(id: string, input: UpdateProductDto, uid: string) {
    if (!Object.keys(input).length)
      throw new BadRequestException('Envía al menos un campo para actualizar.');
    return this.repository.update(id, input, uid);
  }
}
