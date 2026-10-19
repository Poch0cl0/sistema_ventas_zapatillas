import {
  Body,
  Controller,
  Delete,
  Get,
  Header,
  Inject,
  Param,
  Patch,
  Post,
  Query,
  UploadedFiles,
  UseInterceptors,
} from '@nestjs/common';
import { FilesInterceptor } from '@nestjs/platform-express';
import {
  ProductImagesService,
  MAX_IMAGE_BYTES,
  MAX_UPLOAD_IMAGES,
} from './product-images.service.js';
import {
  ApiBearerAuth,
  ApiOperation,
  ApiTags,
  ApiResponse,
  ApiOkResponse,
  ApiCreatedResponse,
  ApiBadRequestResponse,
  ApiNotFoundResponse,
  ApiBody,
  ApiConsumes,
} from '@nestjs/swagger';
import {
  ProductPageDto,
  ProductResponseDto,
} from '../common/dto/responses.dto.js';
import {
  CurrentUser,
  Public,
  Roles,
} from '../common/decorators/auth.decorators.js';
import type { UserProfile } from '../common/auth.types.js';
import { DocumentIdDto, PaginationDto } from '../common/dto/pagination.dto.js';
import { CreateProductDto, UpdateProductDto } from './dto/product.dto.js';
import { ProductsService } from './products.service.js';

@ApiTags('Catálogo público')
@ApiBadRequestResponse({ description: 'Parámetros inválidos.' })
@Public()
@Controller('products')
export class ProductsController {
  constructor(
    @Inject(ProductsService) private readonly products: ProductsService,
  ) {}
  @Get()
  @ApiOkResponse({ type: ProductPageDto })
  @ApiOperation({ summary: 'Listar productos activos; paginación por ID' })
  list(@Query() pagination: PaginationDto) {
    return this.products.list(pagination);
  }
  @Get(':id')
  @ApiOkResponse({ type: ProductResponseDto })
  @ApiOperation({ summary: 'Consultar un producto activo' })
  @ApiResponse({ status: 404, description: 'Producto inexistente o inactivo.' })
  find(@Param() params: DocumentIdDto) {
    return this.products.find(params.id);
  }
  @Get(':id/availability')
  @Header('Cache-Control', 'no-store')
  @ApiOperation({ summary: 'Consultar tallas y unidades disponibles de un producto activo' })
  availability(@Param() params: DocumentIdDto) {
    return this.products.availability(params.id);
  }
}

@ApiTags('Administración de productos')
@ApiBearerAuth()
@ApiBadRequestResponse({
  description: 'Datos inválidos o campos no permitidos.',
})
@ApiNotFoundResponse({ description: 'Producto no encontrado.' })
@ApiResponse({ status: 401, description: 'Sesión requerida o inválida.' })
@ApiResponse({ status: 403, description: 'Solo ADMINISTRADOR.' })
@Roles('ADMINISTRADOR')
@Controller('admin/products')
export class AdminProductsController {
  constructor(
    @Inject(ProductsService) private readonly products: ProductsService,
    @Inject(ProductImagesService) private readonly images: ProductImagesService,
  ) {}
  @Get()
  @ApiOkResponse({ type: ProductPageDto })
  @ApiOperation({ summary: 'Listar productos activos e inactivos' })
  list(@Query() pagination: PaginationDto) {
    return this.products.list(pagination, false);
  }
  @Get(':id')
  @ApiOkResponse({ type: ProductResponseDto })
  @ApiOperation({ summary: 'Consultar producto, incluso inactivo' })
  find(@Param() params: DocumentIdDto) {
    return this.products.find(params.id, false);
  }
  @Post()
  @ApiCreatedResponse({ type: ProductResponseDto })
  @ApiOperation({
    summary:
      'Crear producto; adjuntar fotos después con POST /admin/products/{id}/images',
  })
  create(@Body() input: CreateProductDto, @CurrentUser() user: UserProfile) {
    return this.products.create(input, user.uid);
  }
  @Post(':id/images')
  @ApiOperation({
    summary:
      'Adjuntar de 1 a 5 fotos JPEG, PNG o WebP; máximo 5 MiB por archivo y 10 fotos por producto',
  })
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      required: ['files'],
      properties: {
        files: {
          type: 'array',
          minItems: 1,
          maxItems: MAX_UPLOAD_IMAGES,
          items: { type: 'string', format: 'binary' },
        },
      },
    },
  })
  @ApiCreatedResponse({ type: ProductResponseDto })
  @ApiResponse({ status: 413, description: 'Archivo demasiado grande.' })
  @ApiResponse({
    status: 503,
    description: 'Cloudinary temporalmente no disponible o sin configurar.',
  })
  @UseInterceptors(
    FilesInterceptor('files', MAX_UPLOAD_IMAGES, {
      limits: {
        fileSize: MAX_IMAGE_BYTES,
        files: MAX_UPLOAD_IMAGES,
        fields: 0,
        parts: MAX_UPLOAD_IMAGES + 1,
      },
    }),
  )
  uploadImages(
    @Param() params: DocumentIdDto,
    @UploadedFiles() files: Express.Multer.File[],
    @CurrentUser() user: UserProfile,
  ) {
    return this.images.upload(params.id, files, user.uid);
  }
  @Patch(':id')
  @ApiOkResponse({ type: ProductResponseDto })
  @ApiOperation({ summary: 'Editar producto o reactivarlo con active=true' })
  update(
    @Param() params: DocumentIdDto,
    @Body() input: UpdateProductDto,
    @CurrentUser() user: UserProfile,
  ) {
    return this.products.update(params.id, input, user.uid);
  }
  @Delete(':id')
  @ApiOkResponse({ type: ProductResponseDto })
  @ApiOperation({
    summary: 'Desactivar producto sin borrar su historial ni inventario',
  })
  remove(@Param() params: DocumentIdDto, @CurrentUser() user: UserProfile) {
    return this.products.update(params.id, { active: false }, user.uid);
  }
}
