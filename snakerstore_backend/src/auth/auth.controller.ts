import { Controller, Get, Header } from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiOperation,
  ApiTags,
  ApiOkResponse,
  ApiUnauthorizedResponse,
} from '@nestjs/swagger';
import { CurrentUser } from '../common/decorators/auth.decorators.js';
import type { UserProfile } from '../common/auth.types.js';

@Controller('auth')
@ApiTags('Autenticación')
@ApiBearerAuth()
export class AuthController {
  @Get('me')
  @Header('Cache-Control', 'no-store')
  @ApiOperation({ summary: 'Consultar identidad y rol confiable de Firestore' })
  @ApiUnauthorizedResponse({ description: 'Sesión inválida o ausente.' })
  @ApiOkResponse({
    schema: {
      type: 'object',
      properties: {
        uid: { type: 'string' },
        email: { type: 'string', nullable: true },
        name: { type: 'string', nullable: true },
        role: { type: 'string', enum: ['CLIENTE', 'ADMINISTRADOR'] },
      },
    },
  })
  me(@CurrentUser() user: UserProfile): UserProfile {
    return user;
  }
}
