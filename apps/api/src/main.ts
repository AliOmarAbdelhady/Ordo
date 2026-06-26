import { NestFactory } from '@nestjs/core';
import { ValidationPipe, Logger } from '@nestjs/common';
import { IoAdapter } from '@nestjs/platform-socket.io';
import { AppModule } from './app.module';
import { AllExceptionsFilter } from './common/filters/all-exceptions.filter';

async function bootstrap() {
  const app = await NestFactory.create(AppModule, { bufferLogs: true });

  const port = process.env.PORT ?? 4000;
  const rawOrigin = process.env.CORS_ORIGIN ?? '*';
  const corsOrigin = rawOrigin.split(',');
  // '*' → reflect origin (keeps credentials working in dev). Mobile apps ignore CORS.
  const origin = corsOrigin.includes('*') ? true : corsOrigin;

  app.setGlobalPrefix('api');
  app.enableCors({
    origin,
    credentials: true,
    methods: ['GET', 'POST', 'PATCH', 'PUT', 'DELETE', 'OPTIONS'],
  });
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      forbidNonWhitelisted: false,
      transformOptions: { enableImplicitConversion: true },
    }),
  );
  app.useGlobalFilters(new AllExceptionsFilter());
  // Socket.IO adapter (in-memory for the MVP; swap for Redis adapter at scale).
  app.useWebSocketAdapter(new IoAdapter(app));

  await app.listen(port);
  Logger.log(`🚀 Ordo API ready on http://localhost:${port}/api`, 'Bootstrap');
}
bootstrap();
