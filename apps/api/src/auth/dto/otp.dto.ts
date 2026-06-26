import { IsEnum, IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

export class RequestOtpDto {
  @IsEnum(['phone', 'email'])
  target!: 'phone' | 'email';

  @IsString()
  @MinLength(3)
  @MaxLength(120)
  value!: string;

  @IsOptional()
  @IsEnum(['signup', 'login', 'reset', 'verify_phone', 'verify_email'])
  purpose?: 'signup' | 'login' | 'reset' | 'verify_phone' | 'verify_email';
}

export class VerifyOtpDto {
  @IsEnum(['phone', 'email'])
  target!: 'phone' | 'email';

  @IsString()
  @MinLength(3)
  @MaxLength(120)
  value!: string;

  @IsString()
  @MinLength(4)
  @MaxLength(12)
  code!: string;

  @IsOptional()
  @IsEnum(['signup', 'login', 'reset', 'verify_phone', 'verify_email'])
  purpose?: 'signup' | 'login' | 'reset' | 'verify_phone' | 'verify_email';
}
