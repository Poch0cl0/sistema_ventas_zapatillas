import { Body, Controller, Get, Header, Inject, Put } from '@nestjs/common';
import {
  ApiBadRequestResponse,
  ApiBearerAuth,
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
import {
  PutStoreSettingsDto,
  StoreSettingsResponseDto,
} from './dto/store-settings.dto.js';
import { StoreSettingsService } from './store-settings.service.js';

@ApiTags('Configuración pública de tienda')
@ApiNotFoundResponse({ description: 'Aún no se configuró la tienda.' })
@Public()
@Controller('store-settings')
export class StoreSettingsController {
  constructor(
    @Inject(StoreSettingsService)
    private readonly settings: StoreSettingsService,
  ) {}
  @Get()
  @Header('Cache-Control', 'no-store')
  @ApiOperation({
    summary:
      'Consultar datos de recojo y métodos de pago habilitados; no incluir secretos en esta configuración',
  })
  @ApiOkResponse({ type: StoreSettingsResponseDto })
  get() {
    return this.settings.get(true);
  }
}

@ApiTags('Administración de tienda')
@ApiBearerAuth()
@ApiUnauthorizedResponse({ description: 'Sesión requerida o inválida.' })
@ApiForbiddenResponse({ description: 'Solo ADMINISTRADOR.' })
@ApiBadRequestResponse({
  description: 'Datos inválidos o métodos de pago repetidos.',
})
@Roles('ADMINISTRADOR')
@Controller('admin/store-settings')
export class AdminStoreSettingsController {
  constructor(
    @Inject(StoreSettingsService)
    private readonly settings: StoreSettingsService,
  ) {}
  @Get()
  @Header('Cache-Control', 'no-store')
  @ApiOperation({
    summary:
      'Consultar configuración completa, incluidos métodos deshabilitados',
  })
  @ApiNotFoundResponse({ description: 'Aún no se configuró la tienda.' })
  @ApiOkResponse({ type: StoreSettingsResponseDto })
  get() {
    return this.settings.get(false);
  }
  @Put()
  @ApiOperation({
    summary:
      'Crear o sustituir todos los campos editables de configuración (no es PATCH)',
  })
  @ApiOkResponse({ type: StoreSettingsResponseDto })
  put(@Body() input: PutStoreSettingsDto, @CurrentUser() user: UserProfile) {
    return this.settings.put(input, user.uid);
  }
}
