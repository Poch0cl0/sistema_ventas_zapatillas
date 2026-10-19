import {
  ForbiddenException,
  Inject,
  Injectable,
  ServiceUnavailableException,
} from '@nestjs/common';
import type { DecodedIdToken } from 'firebase-admin/auth';
import type { UserProfile } from '../common/auth.types.js';
import { UsersRepository } from './users.repository.js';

@Injectable()
export class UsersService {
  constructor(
    @Inject(UsersRepository) private readonly repository: UsersRepository,
  ) {}

  async getProfile(identity: DecodedIdToken): Promise<UserProfile> {
    let profile;
    try {
      profile = await this.repository.findOrCreate(identity);
    } catch {
      throw new ServiceUnavailableException(
        'No se pudo consultar el perfil. Intenta nuevamente.',
      );
    }
    if (profile.role !== 'CLIENTE' && profile.role !== 'ADMINISTRADOR') {
      throw new ForbiddenException('El perfil no tiene un rol autorizado.');
    }
    return {
      uid: identity.uid,
      email: identity.email ?? null,
      name: typeof profile.name === 'string' ? profile.name : null,
      role: profile.role,
    };
  }
}
