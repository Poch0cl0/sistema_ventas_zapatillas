import {
  Body,
  Controller,
  Delete,
  Get,
  Inject,
  Param,
  Patch,
  Post,
  Query,
} from '@nestjs/common';
import {
  ApiBadRequestResponse,
  ApiBearerAuth,
  ApiCreatedResponse,
  ApiForbiddenResponse,
  ApiNotFoundResponse,
  ApiOkResponse,
  ApiOperation,
  ApiTags,
  ApiUnauthorizedResponse,
} from '@nestjs/swagger';
import {
  CurrentUser,
  Public,
  Roles,
} from '../common/decorators/auth.decorators.js';
import type { UserProfile } from '../common/auth.types.js';
import { DocumentIdDto, PaginationDto } from '../common/dto/pagination.dto.js';
import {
  CreateDeliveryZoneDto,
  DeliveryZonePageDto,
  DeliveryZoneResponseDto,
  UpdateDeliveryZoneDto,
} from './dto/delivery-zone.dto.js';
import { DeliveryZonesService } from './delivery-zones.service.js';

@ApiTags('Zonas de delivery públicas')
@ApiBadRequestResponse({ description: 'Paginación inválida.' })
@Public()
@Controller('delivery-zones')
export class DeliveryZonesController {
  constructor(
    @Inject(DeliveryZonesService) private readonly zones: DeliveryZonesService,
  ) {}
  @Get()
  @ApiOperation({
    summary: 'Listar zonas activas y sus tarifas en céntimos PEN',
  })
  @ApiOkResponse({ type: DeliveryZonePageDto })
  list(@Query() pagination: PaginationDto) {
    return this.zones.list(pagination, true);
  }
}

@ApiTags('Administración de delivery')
@ApiBearerAuth()
@ApiBadRequestResponse({
  description: 'Datos inválidos o campos no permitidos.',
})
@ApiUnauthorizedResponse({ description: 'Sesión requerida o inválida.' })
@ApiForbiddenResponse({ description: 'Solo ADMINISTRADOR.' })
@ApiNotFoundResponse({ description: 'Zona no encontrada.' })
@Roles('ADMINISTRADOR')
@Controller('admin/delivery-zones')
export class AdminDeliveryZonesController {
  constructor(
    @Inject(DeliveryZonesService) private readonly zones: DeliveryZonesService,
  ) {}
  @Get()
  @ApiOperation({ summary: 'Listar zonas activas e inactivas' })
  @ApiOkResponse({ type: DeliveryZonePageDto })
  list(@Query() pagination: PaginationDto) {
    return this.zones.list(pagination, false);
  }
  @Post()
  @ApiOperation({ summary: 'Crear zona de delivery' })
  @ApiCreatedResponse({ type: DeliveryZoneResponseDto })
  create(
    @Body() input: CreateDeliveryZoneDto,
    @CurrentUser() user: UserProfile,
  ) {
    return this.zones.create(input, user.uid);
  }
  @Patch(':id')
  @ApiOperation({ summary: 'Editar nombre, tarifa o estado de una zona' })
  @ApiOkResponse({ type: DeliveryZoneResponseDto })
  update(
    @Param() params: DocumentIdDto,
    @Body() input: UpdateDeliveryZoneDto,
    @CurrentUser() user: UserProfile,
  ) {
    return this.zones.update(params.id, input, user.uid);
  }
  @Delete(':id')
  @ApiOperation({ summary: 'Desactivar una zona conservando su historial' })
  @ApiOkResponse({ type: DeliveryZoneResponseDto })
  remove(@Param() params: DocumentIdDto, @CurrentUser() user: UserProfile) {
    return this.zones.update(params.id, { active: false }, user.uid);
  }
}
