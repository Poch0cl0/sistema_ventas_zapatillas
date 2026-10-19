import { Module } from '@nestjs/common';
import {
  StoreSettingsController,
  AdminStoreSettingsController,
} from './store-settings.controller.js';
import { StoreSettingsRepository } from './store-settings.repository.js';
import { StoreSettingsService } from './store-settings.service.js';

@Module({
  controllers: [StoreSettingsController, AdminStoreSettingsController],
  providers: [StoreSettingsRepository, StoreSettingsService],
})
export class StoreSettingsModule {}
