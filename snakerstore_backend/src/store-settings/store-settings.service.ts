import { BadRequestException, Inject, Injectable } from '@nestjs/common';
import { StoreSettingsRepository } from './store-settings.repository.js';
import type { PutStoreSettingsDto } from './dto/store-settings.dto.js';

@Injectable()
export class StoreSettingsService {
  constructor(
    @Inject(StoreSettingsRepository)
    private readonly repository: StoreSettingsRepository,
  ) {}
  get(onlyEnabled: boolean) {
    return this.repository.get(onlyEnabled);
  }
  put(input: PutStoreSettingsDto, actorId: string) {
    const methods = input.paymentMethods.map((item) => item.method);
    if (new Set(methods).size !== methods.length)
      throw new BadRequestException('No se puede repetir un método de pago.');
    return this.repository.put(input, actorId);
  }
}
