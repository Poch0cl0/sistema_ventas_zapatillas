import { Body, Controller, Get, Header, Inject, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../common/decorators/auth.decorators.js';
import type { UserProfile } from '../common/auth.types.js';
import { DeliveryRouteDto } from './dto/delivery-route.dto.js';
import { DeliveryService } from './delivery.service.js';

@ApiTags('Mapa de entrega')
@ApiBearerAuth()
@Controller('api/delivery')
export class DeliveryController {
  constructor(
    @Inject(DeliveryService) private readonly delivery: DeliveryService,
  ) {}

  @Get('config')
  @Header('Cache-Control', 'no-store')
  @ApiOperation({
    summary:
      'Coordenadas de tienda y configuración pública del mapa; nunca devuelve la clave ORS',
  })
  config() {
    return this.delivery.publicConfig();
  }

  @Post('route')
  @Header('Cache-Control', 'no-store')
  @ApiOperation({
    summary:
      'Ruta estimada de automóvil desde la tienda al destino seleccionado; requiere sesión',
  })
  route(@Body() input: DeliveryRouteDto, @CurrentUser() user: UserProfile) {
    return this.delivery.route(input, user.uid, user.role === 'ADMINISTRADOR');
  }
}
