import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { Request, Response } from 'express';
import { Prisma } from '@prisma/client';

/**
 * Normalizes every error into a consistent JSON envelope:
 * { error: { code, message, details? } }
 */
@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger('Exception');

  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();

    let status = HttpStatus.INTERNAL_SERVER_ERROR;
    let message = 'Internal server error';
    let code = 'INTERNAL_ERROR';
    let details: unknown;

    if (exception instanceof HttpException) {
      status = exception.getStatus();
      const res = exception.getResponse();
      if (typeof res === 'string') {
        message = res;
      } else if (typeof res === 'object' && res !== null) {
        const r = res as Record<string, unknown>;
        message = (r.message as string) || exception.message;
        details = r.message && Array.isArray(r.message) ? r.message : r.error;
        code = (r.code as string) ?? code;
      }
      code = code === 'INTERNAL_ERROR' ? toCode(status) : code;
    } else if (exception instanceof Prisma.PrismaClientKnownRequestError) {
      // P2002 unique constraint, P2025 not found
      if (exception.code === 'P2002') {
        status = HttpStatus.CONFLICT;
        code = 'CONFLICT';
        message = 'A record with this value already exists.';
        details = exception.meta;
      } else if (exception.code === 'P2025') {
        status = HttpStatus.NOT_FOUND;
        code = 'NOT_FOUND';
        message = 'Record not found.';
      } else {
        code = exception.code;
      }
    }
    // NOTE: we intentionally do NOT forward raw Error.message for unhandled
    // (non-HttpException) errors — those would leak internal details (stack-derived
    // messages, library errors, assertion text) to clients. The default
    // "Internal server error" is returned instead; the real error is logged below.

    if (status >= 500) {
      this.logger.error(
        `${request.method} ${request.url} → ${status}`,
        exception instanceof Error ? exception.stack : String(exception),
      );
    }

    response.status(status).json({
      error: { code, message, ...(details ? { details } : undefined) },
    });
  }
}

function toCode(status: number): string {
  switch (status) {
    case 400:
      return 'BAD_REQUEST';
    case 401:
      return 'UNAUTHORIZED';
    case 403:
      return 'FORBIDDEN';
    case 404:
      return 'NOT_FOUND';
    case 409:
      return 'CONFLICT';
    case 422:
      return 'UNPROCESSABLE_ENTITY';
    default:
      return 'ERROR';
  }
}
