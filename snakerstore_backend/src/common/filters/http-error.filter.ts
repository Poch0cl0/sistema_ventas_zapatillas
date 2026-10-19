import { Catch, HttpException } from '@nestjs/common';
import type { ArgumentsHost, ExceptionFilter } from '@nestjs/common';
import type { Response } from 'express';

@Catch()
export class HttpErrorFilter implements ExceptionFilter {
  catch(error: unknown, host: ArgumentsHost) {
    const response = host.switchToHttp().getResponse<Response>();
    const code =
      error && typeof error === 'object' && 'code' in error
        ? error.code
        : undefined;
    const status =
      error instanceof HttpException
        ? error.getStatus()
        : [4, 8, 10, 14].includes(Number(code))
          ? 503
          : 500;
    const body = error instanceof HttpException ? error.getResponse() : null;
    const message =
      typeof body === 'string'
        ? body
        : body && typeof body === 'object' && 'message' in body
          ? body.message
          : status === 503
            ? 'Servicio temporalmente no disponible.'
            : 'No se pudo completar la operación.';
    response.status(status).json({ statusCode: status, message });
  }
}
