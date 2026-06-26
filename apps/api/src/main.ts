import { NestFactory } from '@nestjs/core';
import { ValidationPipe, Logger } from '@nestjs/common';
import { IoAdapter } from '@nestjs/platform-socket.io';
import { NestExpressApplication } from '@nestjs/platform-express';
import { AppModule } from './app.module';
import { AllExceptionsFilter } from './common/filters/all-exceptions.filter';

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule, { bufferLogs: true });

  const port = process.env.PORT ?? 4000;
  const rawOrigin = process.env.CORS_ORIGIN ?? '';
  const list = rawOrigin ? rawOrigin.split(',').map((o) => o.trim()).filter(Boolean) : [];
  const wildcard = list.includes('*');
  // No env / empty -> no CORS (mobile & desktop clients are unaffected; only a
  // future browser client would need an explicit allowlist). '*' -> reflect the
  // request Origin (dev convenience).
  const origin = wildcard ? true : list.length ? list : false;
  // Reflecting arbitrary origins is incompatible with credentialed CORS and would
  // let any site make credentialed cross-origin requests. The API authenticates
  // with Bearer tokens (not cookies), so credentials are only enabled for an
  // explicit origin allowlist.
  const credentials = !wildcard;

  app.setGlobalPrefix('api');
  // Cap request body size to bound oversized payloads (DoS). 2 MB covers all
  // JSON endpoints; file uploads go through multipart and are size-checked in
  // MediaService (10 MB cap).
  app.useBodyParser('json', { limit: '2mb' });
  app.useBodyParser('urlencoded', { limit: '2mb', extended: true });
  app.enableCors({
    origin,
    credentials,
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
