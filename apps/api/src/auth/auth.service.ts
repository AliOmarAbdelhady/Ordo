import {
  ConflictException,
  Inject,
  Injectable,
  Logger,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { PrismaService } from '../prisma/prisma.service';
import { RegisterDto, LoginDto } from './dto/auth.dto';
import { compare, genSalt, hash } from 'bcryptjs';
import { User } from '@prisma/client';

export interface AuthTokens {
  accessToken: string;
  refreshToken: string;
}

export interface PublicUser {
  id: string;
  email: string;
  name: string;
  username: string;
  avatarUrl: string | null;
  timezone: string;
  theme: string;
  accentColor: string;
  bio: string | null;
  createdAt: string;
}

export function toPublicUser(user: User): PublicUser {
  return {
    id: user.id,
    email: user.email,
    name: user.name,
    username: user.username,
    avatarUrl: user.avatarUrl,
    timezone: user.timezone,
    theme: user.theme,
    accentColor: user.accentColor,
    bio: user.bio,
    createdAt: user.createdAt.toISOString(),
  };
}

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
    @Inject('BCRYPT_ROUNDS') private readonly rounds: number,
  ) {}

  async register(dto: RegisterDto, meta: { userAgent?: string; ip?: string }) {
    const exists = await this.prisma.user.findFirst({
      where: { OR: [{ email: dto.email }, { username: dto.username }] },
      select: { id: true },
    });
    if (exists) throw new ConflictException('Email or username already in use');

    const passwordHash = await hash(dto.password, await genSalt(this.rounds));
    const user = await this.prisma.user.create({
      data: {
        name: dto.name,
        email: dto.email,
        username: dto.username,
        passwordHash,
        emailVerified: false,
        availabilityPrefs: { create: {} },
      },
    });

    const tokens = await this.issueSession(user, meta);
    return { user: toPublicUser(user), ...tokens };
  }

  async login(dto: LoginDto, meta: { userAgent?: string; ip?: string }) {
    const user = await this.prisma.user.findFirst({
      where: { OR: [{ email: dto.email }, { username: dto.email }] },
    });
    if (!user || user.deletedAt) throw new UnauthorizedException('Invalid credentials');

    const ok = await compare(dto.password, user.passwordHash);
    if (!ok) throw new UnauthorizedException('Invalid credentials');

    const tokens = await this.issueSession(user, meta);
    return { user: toPublicUser(user), ...tokens };
  }

  async refresh(refreshToken: string, meta: { userAgent?: string; ip?: string }) {
    let payload: { sub: string; sid: string };
    try {
      payload = await this.jwt.verifyAsync(refreshToken, {
        secret: this.config.get<string>('JWT_REFRESH_SECRET'),
      });
    } catch {
      throw new UnauthorizedException('Invalid refresh token');
    }

    const session = await this.prisma.session.findFirst({
      where: { id: payload.sid, userId: payload.sub, revokedAt: null },
    });
    if (!session) throw new UnauthorizedException('Session not found');

    const matches = await compare(refreshToken, session.refreshTokenHash);
    if (!matches) {
      // Possible token reuse — revoke the whole session to be safe.
      await this.prisma.session.update({ where: { id: session.id }, data: { revokedAt: new Date() } });
      throw new UnauthorizedException('Refresh token mismatch');
    }

    const user = await this.prisma.user.findUnique({ where: { id: payload.sub } });
    if (!user || user.deletedAt) throw new UnauthorizedException('Account unavailable');

    // Rotate: revoke old, issue new.
    await this.prisma.session.update({ where: { id: session.id }, data: { revokedAt: new Date() } });
    const tokens = await this.issueSession(user, meta);
    return { user: toPublicUser(user), ...tokens };
  }

  async logout(refreshToken?: string) {
    if (!refreshToken) return { ok: true };
    try {
      const payload = await this.jwt.verifyAsync(refreshToken, {
        secret: this.config.get<string>('JWT_REFRESH_SECRET'),
      });
      await this.prisma.session.updateMany({
        where: { id: payload.sid, userId: payload.sub },
        data: { revokedAt: new Date() },
      });
    } catch {
      /* ignore — token invalid, nothing to revoke */
    }
    return { ok: true };
  }

  async me(userId: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new NotFoundException('User not found');
    return toPublicUser(user);
  }

  async listSessions(userId: string) {
    const sessions = await this.prisma.session.findMany({
      where: { userId, revokedAt: null, expiresAt: { gt: new Date() } },
      orderBy: { createdAt: 'desc' },
      select: { id: true, userAgent: true, ip: true, createdAt: true, expiresAt: true },
    });
    return { sessions };
  }

  async revokeSession(userId: string, sessionId: string) {
    const updated = await this.prisma.session.updateMany({
      where: { id: sessionId, userId },
      data: { revokedAt: new Date() },
    });
    if (updated.count === 0) throw new NotFoundException('Session not found');
    return { ok: true };
  }

  private async issueSession(user: User, meta: { userAgent?: string; ip?: string }): Promise<AuthTokens> {
    const refreshTtl = this.parseTtl(this.config.get<string>('JWT_REFRESH_TTL') ?? '60d');
    const expiresAt = new Date(Date.now() + refreshTtl);

    const access = await this.jwt.signAsync(
      { sub: user.id, email: user.email, name: user.name },
      {
        secret: this.config.get<string>('JWT_ACCESS_SECRET'),
        expiresIn: this.config.get<string>('JWT_ACCESS_TTL') ?? '15m',
      },
    );

    const refresh = await this.jwt.signAsync(
      { sub: user.id, sid: '' },
      { secret: this.config.get<string>('JWT_REFRESH_SECRET'), expiresIn: '60d' },
    );

    // We need the session id inside the refresh token, so create the session
    // first with a placeholder, then re-sign with the real sid.
    const session = await this.prisma.session.create({
      data: {
        userId: user.id,
        refreshTokenHash: await hash(refresh, await genSalt(this.rounds)),
        userAgent: meta.userAgent,
        ip: meta.ip,
        expiresAt,
      },
    });

    const finalRefresh = await this.jwt.signAsync(
      { sub: user.id, sid: session.id },
      { secret: this.config.get<string>('JWT_REFRESH_SECRET'), expiresIn: '60d' },
    );
    await this.prisma.session.update({
      where: { id: session.id },
      data: { refreshTokenHash: await hash(finalRefresh, await genSalt(this.rounds)) },
    });

    return { accessToken: access, refreshToken: finalRefresh };
  }

  private parseTtl(ttl: string): number {
    const m = /^(\d+)([smhd])$/.exec(ttl);
    if (!m) return 60 * 24 * 60 * 60 * 1000;
    const n = Number(m[1]);
    const unit = m[2];
    const mult = unit === 's' ? 1000 : unit === 'm' ? 60_000 : unit === 'h' ? 3_600_000 : 86_400_000;
    return n * mult;
  }
}
