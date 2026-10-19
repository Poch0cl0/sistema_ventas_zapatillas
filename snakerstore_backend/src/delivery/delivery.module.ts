import { Module } from '@nestjs/common';
import { HttpModule } from '@nestjs/axios';
import { DeliveryController } from './delivery.controller.js';
import { DeliveryService } from './delivery.service.js';

@Module({
  imports: [HttpModule.register({ timeout: 15000, maxRedirects: 0,
    maxContentLength: 4 * 1024 * 1024, maxBodyLength: 8192 })],
  controllers: [DeliveryController],
  providers: [DeliveryService],
})
export class DeliveryModule {}
