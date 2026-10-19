import { Controller, Get } from '@nestjs/common';
import { Public } from './common/decorators/auth.decorators.js';
import { AppService } from './app.service.js';

@Controller()
export class AppController {
  constructor(private readonly appService: AppService) {}

  @Get()
  @Public()
  getHello(): string {
    return this.appService.getHello();
  }
}
