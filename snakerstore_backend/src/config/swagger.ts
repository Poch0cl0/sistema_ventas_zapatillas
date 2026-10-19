import type { INestApplication } from '@nestjs/common';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';

export function configureSwagger(app: INestApplication) {
  const config = new DocumentBuilder()
    .setTitle('SneakerStore API')
    .setDescription(
      'API REST. Importes en céntimos PEN. Autoriza con un ID token de Firebase; las escrituras requieren ADMINISTRADOR.',
    )
    .setVersion('1.0')
    .addBearerAuth({
      type: 'http',
      scheme: 'bearer',
      bearerFormat: 'Firebase ID token',
    })
    .build();
  const document = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup('docs', app, document, {
    swaggerOptions: { persistAuthorization: false },
    customSiteTitle: 'SneakerStore API',
  });
  return document;
}
