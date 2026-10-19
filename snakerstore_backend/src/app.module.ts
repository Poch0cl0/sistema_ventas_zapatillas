import { Module, ValidationPipe } from '@nestjs/common';
import { DeliveryModule } from './delivery/delivery.module.js';
import { OrdersModule } from './orders/orders.module.js';
import { DeliveryZonesModule } from './delivery-zones/delivery-zones.module.js';
import { StoreSettingsModule } from './store-settings/store-settings.module.js';
import { APP_FILTER, APP_PIPE } from '@nestjs/core';
import { HttpErrorFilter } from './common/filters/http-error.filter.js';
import { ProductsModule } from './products/products.module.js';
import { InventoryModule } from './inventory/inventory.module.js';
import { AuthModule } from './auth/auth.module.js';
import { ConfigModule } from '@nestjs/config';
import { validateEnvironment } from './config/environment.js';
import { FirebaseModule } from './firebase/firebase.module.js';
import { AppController } from './app.controller.js';
import { AppService } from './app.service.js';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true, validate: validateEnvironment }),
    FirebaseModule,
    AuthModule,
    ProductsModule,
    InventoryModule,
    DeliveryZonesModule,
    StoreSettingsModule,
    OrdersModule,
    DeliveryModule,
  ],
  controllers: [AppController],
  providers: [
    AppService,
    {
      provide: APP_PIPE,
      useFactory: () =>
        new ValidationPipe({
          whitelist: true,
          forbidNonWhitelisted: true,
          transform: true,
          validationError: { target: false, value: false },
        }),
    },
    { provide: APP_FILTER, useClass: HttpErrorFilter },
  ],
})
export class AppModule {}
