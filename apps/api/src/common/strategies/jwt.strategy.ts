import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { RequestUser } from '../decorators/current-user.decorator';
import { PrismaService } from '../../prisma/prisma.service';

interface JwtPayload {
  sub: string;
  email?: string;
  name?: string;
  sid?: string;
}

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy, 'jwt') {
  constructor(
    config: ConfigService,
    private readonly prisma: PrismaService,
  ) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: config.get<string>('JWT_ACCESS_SECRET') ?? 'dev_access_secret',
    });
  }

  async validate(payload: JwtPayload): Promise<RequestUser> {
    // Reject tokens whose account was deleted after the token was minted, so
    // account deletion takes effect immediately rather than after the access TTL.
    // (We deliberately do NOT do a per-request session-revocation lookup: refresh
    // rotation creates a new session each refresh, which would invalidate in-flight
    // access tokens and cause cascading 401s. Logout still revokes sessions, and
    // refresh-token reuse detection revokes on mismatch; the short access TTL is
    // the standard mitigation for a stolen access token.)
    const user = await this.prisma.user.findUnique({
      where: { id: payload.sub },
      select: { id: true, deletedAt: true },
    });
    if (!user || user.deletedAt) {
      throw new UnauthorizedException('Account unavailable');
    }

    return { id: payload.sub, email: payload.email, name: payload.name };
  }
}
