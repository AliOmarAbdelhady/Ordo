import {
  BadRequestException,
  ConflictException,
  HttpException,
  HttpStatus,
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
import { randomInt } from 'crypto';
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
  // In-memory OTP rate limiter (key -> {count, resetAt}). Fine for a single
  // instance MVP; swap for Redis when scaling out. Bounds OTP issuance/verify
  // brute-force and per-target flooding.
  private readonly otpLimits = new Map<string, { count: number; resetAt: number }>();

  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
    @Inject('BCRYPT_ROUNDS') private readonly rounds: number,
  ) {}

  private enforceRateLimit(key: string, max: number, windowMs: number) {
    const now = Date.now();
    const entry = this.otpLimits.get(key);
    if (!entry || entry.resetAt < now) {
      this.otpLimits.set(key, { count: 1, resetAt: now + windowMs });
      return;
    }
    entry.count += 1;
    if (entry.count > max) {
      throw new HttpException('Too many attempts, please try again later', HttpStatus.TOO_MANY_REQUESTS);
    }
  }

  async register(dto: RegisterDto, meta: { userAgent?: string; ip?: string }) {
    // Emails are case-insensitive: normalize to lowercase everywhere so that
    // Foo@x.com and foo@x.com cannot register as two accounts and so login
    // always matches regardless of casing. (DB @unique is case-sensitive.)
    const email = dto.email.toLowerCase().trim();
    const exists = await this.prisma.user.findFirst({
      where: { OR: [{ email }, { username: dto.username }] },
      select: { id: true },
    });
    if (exists) throw new ConflictException('Email or username already in use');

    const passwordHash = await hash(dto.password, await genSalt(this.rounds));
    const user = await this.prisma.user.create({
      data: {
        name: dto.name,
        email,
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
    // Accept either an email or a username. Normalize so email casing and
    // surrounding whitespace never cause a mismatch against the stored row.
    const identifier = dto.email.toLowerCase().trim();
    const user = await this.prisma.user.findFirst({
      where: { OR: [{ email: identifier }, { username: dto.email.trim() }] },
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
    const refreshTtlStr = this.config.get<string>('JWT_REFRESH_TTL') ?? '60d';
    const refreshTtlMs = this.parseTtl(refreshTtlStr);
    const expiresAt = new Date(Date.now() + refreshTtlMs);
    const accessTtlStr = this.config.get<string>('JWT_ACCESS_TTL') ?? '15m';

    // Create the session row first so its id can be embedded in BOTH tokens.
    // The refresh token's sid is verified on refresh; the access token's sid tags
    // the issuing session. Access-token revocation relies on the short access TTL
    // plus session revocation on logout/reuse — NOT a per-request session lookup
    // (which would cascade 401s across refresh rotation). Deleted accounts are
    // rejected immediately via the JwtStrategy deletedAt check.
    const session = await this.prisma.session.create({
      data: {
        userId: user.id,
        refreshTokenHash: 'pending', // overwritten below once the real token is signed
        userAgent: meta.userAgent,
        ip: meta.ip,
        expiresAt,
      },
    });

    const access = await this.jwt.signAsync(
      { sub: user.id, email: user.email, name: user.name, sid: session.id },
      {
        secret: this.config.get<string>('JWT_ACCESS_SECRET'),
        expiresIn: accessTtlStr,
      },
    );

    const refresh = await this.jwt.signAsync(
      { sub: user.id, sid: session.id },
      { secret: this.config.get<string>('JWT_REFRESH_SECRET'), expiresIn: refreshTtlStr },
    );

    await this.prisma.session.update({
      where: { id: session.id },
      data: { refreshTokenHash: await hash(refresh, await genSalt(this.rounds)) },
    });

    return { accessToken: access, refreshToken: refresh };
  }

  private parseTtl(ttl: string): number {
    const m = /^(\d+)([smhd])$/.exec(ttl);
    if (!m) return 60 * 24 * 60 * 60 * 1000;
    const n = Number(m[1]);
    const unit = m[2];
    const mult = unit === 's' ? 1000 : unit === 'm' ? 60_000 : unit === 'h' ? 3_600_000 : 86_400_000;
    return n * mult;
  }

  // ── OTP verification (phone / email) ───────────────────────────────────────
  // Dev-only note: there is no SMS/email provider wired up, so the issued code
  // is returned in the response under `devCode` for local development. In
  // production this would be delivered out-of-band and `devCode` omitted.
  async requestOtp(dto: { target: 'phone' | 'email'; value: string; purpose?: string }) {
    const purpose = dto.purpose ?? 'signup';
    const value = dto.value.toLowerCase().trim();

    // Bound OTP issuance per target+purpose (and globally per value) to prevent
    // flooding / cost amplification once a real SMS/email provider is wired up.
    this.enforceRateLimit(`otp:req:${dto.target}:${value}:${purpose}`, 5, 10 * 60 * 1000);
    this.enforceRateLimit(`otp:req:${value}`, 10, 10 * 60 * 1000);

    // Cryptographically secure 6-digit code (Math.random is not CSPRNG).
    const code = String(randomInt(100000, 1000000));
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000); // 10 minutes
    await this.prisma.verificationCode.create({
      data: {
        target: dto.target,
        value,
        codeHash: await hash(code, await genSalt(this.rounds)),
        purpose,
        expiresAt,
      },
    });
    // devCode is for local development ONLY — it must never leak in production,
    // or any caller could read the verification code for an arbitrary target
    // from the HTTP response and bypass every OTP-protected flow.
    const isDev = this.config.get<string>('NODE_ENV') !== 'production';
    return {
      sent: true,
      purpose,
      expiresAt: expiresAt.toISOString(),
      ...(isDev ? { devCode: code } : {}),
    };
  }

  async verifyOtp(dto: { target: 'phone' | 'email'; value: string; code: string; purpose?: string }) {
    const value = dto.value.toLowerCase().trim();
    const purpose = dto.purpose ?? 'signup';

    // Throttle brute-force attempts per target+purpose across all codes.
    this.enforceRateLimit(`otp:ver:${dto.target}:${value}:${purpose}`, 20, 10 * 60 * 1000);

    const now = new Date();
    // Consider ALL unconsumed, non-expired candidates — a user may have
    // requested several codes and any of them should verify, not only the
    // newest (the previous newest-only logic made older valid codes unusable).
    const candidates = await this.prisma.verificationCode.findMany({
      where: { value, target: dto.target, purpose, consumedAt: null, expiresAt: { gt: now } },
      orderBy: { createdAt: 'desc' },
    });

    let matched: (typeof candidates)[number] | null = null;
    for (const c of candidates) {
      if (c.attempts >= 5) continue;
      if (await compare(dto.code, c.codeHash)) {
        matched = c;
        break;
      }
    }

    if (!matched) {
      // Burn an attempt on the newest still-eligible candidate so repeated
      // guessing locks the code out instead of retrying forever.
      const newest = candidates.find((c) => c.attempts < 5);
      if (newest) {
        await this.prisma.verificationCode.update({
          where: { id: newest.id },
          data: { attempts: { increment: 1 } },
        });
      }
      throw new UnauthorizedException(candidates.length ? 'Invalid code' : 'No code requested');
    }

    // Atomic consumption: only marks used if still unconsumed, preventing
    // double-use under concurrent verify requests.
    const consumed = await this.prisma.verificationCode.updateMany({
      where: { id: matched.id, consumedAt: null },
      data: { consumedAt: now },
    });
    if (consumed.count === 0) throw new UnauthorizedException('Code already used');

    return { verified: true, target: dto.target, value };
  }

  /** Mark the caller's phone/email as verified after a successful OTP. */
  async markVerified(userId: string, target: 'phone' | 'email', value: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, email: true },
    });
    if (!user) throw new NotFoundException('User not found');

    if (target === 'email') {
      // The verified value must be the caller's own account email — otherwise a
      // user could "verify" an arbitrary address they only proved receipt of.
      if (user.email.toLowerCase() !== value.toLowerCase().trim()) {
        throw new BadRequestException('Email does not match your account');
      }
      const updated = await this.prisma.user.update({
        where: { id: userId },
        data: { emailVerified: true },
      });
      return toPublicUser(updated);
    }

    const updated = await this.prisma.user.update({
      where: { id: userId },
      data: { phoneVerified: true, phone: value.trim() },
    });
    return toPublicUser(updated);
  }
}
