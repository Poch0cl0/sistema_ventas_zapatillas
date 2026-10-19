import {
  Inject,
  Injectable,
  ServiceUnavailableException,
  UnauthorizedException,
} from '@nestjs/common';
import type { CanActivate, ExecutionContext } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import type { Auth, DecodedIdToken } from 'firebase-admin/auth';
import { FIREBASE_AUTH } from '../../firebase/firebase.providers.js';
import { UsersService } from '../../users/users.service.js';
import { PUBLIC_ROUTE } from '../decorators/auth.decorators.js';
import type { AuthenticatedRequest } from '../auth.types.js';

@Injectable()
export class FirebaseAuthGuard implements CanActivate {
  constructor(
    @Inject(Reflector) private readonly reflector: Reflector,
    @Inject(FIREBASE_AUTH) private readonly auth: Auth,
    @Inject(UsersService) private readonly users: UsersService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    if (
      this.reflector.getAllAndOverride<boolean>(PUBLIC_ROUTE, [
        context.getHandler(),
        context.getClass(),
      ])
    )
      return true;
    const request = context.switchToHttp().getRequest<AuthenticatedRequest>();
    const header = request.headers.authorization;
    const match =
      typeof header === 'string' ? /^Bearer ([^\s]+)$/i.exec(header) : null;
    if (!match)
      throw new UnauthorizedException('Se requiere un token de Firebase.');
    let identity: DecodedIdToken;
    try {
      identity = await this.auth.verifyIdToken(match[1], true);
    } catch (error: unknown) {
      const code =
        error && typeof error === 'object' && 'code' in error
          ? error.code
          : undefined;
      if (
        code === 'auth/internal-error' ||
        code === 'app/network-error' ||
        code === 'auth/network-request-failed'
      ) {
        throw new ServiceUnavailableException(
          'Firebase no está disponible. Intenta nuevamente.',
        );
      }
      throw new UnauthorizedException(
        'La sesión es inválida o expiró. Inicia sesión nuevamente.',
      );
    }
    request.user = await this.users.getProfile(identity);
    return true;
  }
}
