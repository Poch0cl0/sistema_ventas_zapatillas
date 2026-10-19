import {
  Body,
  Controller,
  Get,
  Inject,
  Param,
  Patch,
  Post,
  Query,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiOperation,
  ApiResponse,
  ApiTags,
  ApiOkResponse,
  ApiCreatedResponse,
  ApiBadRequestResponse,
  ApiNotFoundResponse,
} from '@nestjs/swagger';
import {
  InventoryPageDto,
  InventoryResponseDto,
  MovementPageDto,
} from '../common/dto/responses.dto.js';
import { CurrentUser, Roles } from '../common/decorators/auth.decorators.js';
import type { UserProfile } from '../common/auth.types.js';
import {
  AdjustInventoryDto,
  CreateInventoryDto,
  InventoryIdDto,
  InventoryQueryDto,
  MovementQueryDto,
} from './dto/inventory.dto.js';
import { InventoryService } from './inventory.service.js';

@ApiTags('Inventario administrativo')
@ApiBearerAuth()
@ApiBadRequestResponse({
  description: 'Datos inválidos o campos no permitidos.',
})
@ApiNotFoundResponse({ description: 'Producto o inventario no encontrado.' })
@ApiResponse({ status: 401, description: 'Sesión requerida o inválida.' })
@ApiResponse({ status: 403, description: 'Solo ADMINISTRADOR.' })
@ApiResponse({
  status: 409,
  description:
    'Talla duplicada, stock insuficiente o inventario inconsistente.',
})
@Roles('ADMINISTRADOR')
@Controller('admin/inventory')
export class InventoryController {
  constructor(
    @Inject(InventoryService) private readonly inventory: InventoryService,
  ) {}
  @Get()
  @ApiOkResponse({ type: InventoryPageDto })
  @ApiOperation({ summary: 'Listar existencias por producto/talla' })
  list(@Query() query: InventoryQueryDto) {
    return this.inventory.list(query);
  }
  @Get('movements')
  @ApiOkResponse({ type: MovementPageDto })
  @ApiOperation({
    summary: 'Consultar auditoría de movimientos; paginación por ID',
  })
  movements(@Query() query: MovementQueryDto) {
    return this.inventory.movements(query);
  }
  @Post()
  @ApiCreatedResponse({ type: InventoryResponseDto })
  @ApiOperation({
    summary: 'Crear talla con stock inicial y movimiento atómicos',
  })
  create(@Body() input: CreateInventoryDto, @CurrentUser() user: UserProfile) {
    return this.inventory.create(input, user.uid);
  }
  @Patch(':id')
  @ApiOkResponse({ type: InventoryResponseDto })
  @ApiOperation({
    summary:
      'Ajustar stock disponible y registrar movimiento en una transacción',
  })
  adjust(
    @Param() params: InventoryIdDto,
    @Body() input: AdjustInventoryDto,
    @CurrentUser() user: UserProfile,
  ) {
    return this.inventory.adjust(params.id, input, user.uid);
  }
}
