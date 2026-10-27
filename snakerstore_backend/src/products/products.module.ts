import { Module } from '@nestjs/common';
import {
  ProductsController,
  AdminProductsController,
} from './products.controller.js';
import { ProductsRepository } from './products.repository.js';
import { ProductsService } from './products.service.js';
import { CloudinaryModule } from '../cloudinary/cloudinary.module.js';
import { ProductImagesService } from './product-images.service.js';
import { ProductModelService } from './product-model.service.js';
import { DefaultProductsService } from './default-products.js';

@Module({
  imports: [CloudinaryModule],
  controllers: [ProductsController, AdminProductsController],
  providers: [
    ProductsRepository,
    ProductsService,
    ProductImagesService,
    ProductModelService,
    DefaultProductsService,
  ],
})
export class ProductsModule {}
