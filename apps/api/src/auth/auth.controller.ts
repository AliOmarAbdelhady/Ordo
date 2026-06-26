import { BadRequestException, Body, Controller, Delete, Get, Param, Post, Req } from '@nestjs/common';
import { Request } from 'express';
import { AuthService } from './auth.service';
import { RegisterDto, LoginDto, RefreshDto } from './dto/auth.dto';
import { RequestOtpDto, VerifyOtpDto } from './dto/otp.dto';
import { Public } from '../common/decorators/public.decorator';
import { CurrentUser } from '../common/decorators/current-user.decorator';

function clientMeta(req: Request) {
  return {
    userAgent: req.headers['user-agent'],
    ip: (req.headers['x-forwarded-for'] as string)?.split(',')[0]?.trim() || req.ip,
  };
}

@Controller('auth')
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @Public()
  @Post('register')
  register(@Body() dto: RegisterDto, @Req() req: Request) {
    return this.auth.register(dto, clientMeta(req));
  }

  @Public()
  @Post('login')
  login(@Body() dto: LoginDto, @Req() req: Request) {
    return this.auth.login(dto, clientMeta(req));
  }

  @Public()
  @Post('refresh')
  refresh(@Body() dto: RefreshDto, @Req() req: Request) {
    return this.auth.refresh(dto.refreshToken, clientMeta(req));
  }

  @Post('logout')
  logout(@Body() body: { refreshToken?: string }) {
    return this.auth.logout(body?.refreshToken);
  }

  @Get('me')
  me(@CurrentUser('id') userId: string) {
    return this.auth.me(userId);
  }

  @Get('sessions')
  sessions(@CurrentUser('id') userId: string) {
    return this.auth.listSessions(userId);
  }

  @Delete('sessions/:id')
  revoke(@CurrentUser('id') userId: string, @Param('id') sessionId: string) {
    return this.auth.revokeSession(userId, sessionId);
  }

  @Public()
  @Post('request-otp')
  requestOtp(@Body() dto: RequestOtpDto) {
    return this.auth.requestOtp(dto);
  }

  @Public()
  @Post('verify-otp')
  verifyOtp(@Body() dto: VerifyOtpDto) {
    return this.auth.verifyOtp(dto);
  }

  @Post('verify-phone')
  verifyPhone(@CurrentUser('id') userId: string, @Body() dto: VerifyOtpDto) {
    if (dto.target !== 'phone') {
      throw new BadRequestException('Use the email verification endpoint to verify an email');
    }
    // verifyOtp throws on an invalid/expired code, so markVerified only runs on
    // success. markVerified normalizes the value and guards ownership.
    return this.auth.verifyOtp(dto).then(() => this.auth.markVerified(userId, 'phone', dto.value));
  }

  @Post('verify-email')
  verifyEmail(@CurrentUser('id') userId: string, @Body() dto: VerifyOtpDto) {
    if (dto.target !== 'email') {
      throw new BadRequestException('Use the phone verification endpoint to verify a phone');
    }
    return this.auth.verifyOtp(dto).then(() => this.auth.markVerified(userId, 'email', dto.value));
  }
}
