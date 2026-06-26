import { IsEmail, IsString, Matches, MinLength, MaxLength } from 'class-validator';

export class RegisterDto {
  @IsString()
  @MinLength(1)
  @MaxLength(80)
  name!: string;

  @IsEmail()
  email!: string;

  @IsString()
  @Matches(/^[a-z0-9_]{3,20}$/, {
    message: 'username must be 3-20 chars: lowercase letters, numbers, underscore',
  })
  username!: string;

  @IsString()
  @MinLength(8)
  @MaxLength(100)
  password!: string;
}

export class LoginDto {
  // Accepts either an email or a username — the service matches both. Using
  // @IsEmail here previously rejected usernames, making username login dead code.
  @IsString()
  @MinLength(3)
  @MaxLength(120)
  email!: string;

  @IsString()
  password!: string;
}

export class RefreshDto {
  @IsString()
  refreshToken!: string;
}
