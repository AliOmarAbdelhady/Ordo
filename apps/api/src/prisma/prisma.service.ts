import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';

@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(PrismaService.name);

  async onModuleInit() {
    try {
      await this.$connect();
      this.logger.log('Connected to PostgreSQL');
    } catch (err) {
      // A DB-dependent service cannot run without its database. Log a clear
      // fatal message and exit so the process manager restarts us cleanly,
      // rather than propagating an opaque unhandled rejection.
      this.logger.error(`Failed to connect to PostgreSQL: ${(err as Error).message}`);
      // eslint-disable-next-line no-process-exit
      process.exit(1);
    }
  }

  async onModuleDestroy() {
    await this.$disconnect();
  }
}
