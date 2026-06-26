import { GroupType } from '@prisma/client';
import { IsBoolean, IsEnum, IsIn, IsObject, IsOptional, IsString, IsUrl, MaxLength, MinLength } from 'class-validator';

// accentColor is a NAMED token shared with the Flutter OrdoAccent enum
// (lib/core/app_theme.dart) and the backend group templates / seed data — NOT a
// hex string. Validate against this allowlist so the app's values are accepted.
const ORDO_ACCENTS = ['blue', 'rose', 'emerald', 'violet', 'amber', 'orange', 'cyan', 'slate'] as const;

export class CreateGroupDto {
  @IsString()
  @MinLength(1)
  @MaxLength(80)
  name!: string;

  @IsEnum(GroupType)
  @IsOptional()
  type?: GroupType;

  @IsString()
  @IsOptional()
  @MaxLength(280)
  description?: string;

  @IsUrl({ require_protocol: true, protocols: ['http', 'https'] })
  @IsOptional()
  @MaxLength(2048)
  avatarUrl?: string;

  @IsString()
  @IsOptional()
  @IsIn(ORDO_ACCENTS, { message: 'accentColor must be a valid accent name' })
  accentColor?: string;

  @IsObject()
  @IsOptional()
  modules?: Record<string, boolean>;
}

export class UpdateGroupDto {
  @IsString()
  @IsOptional()
  @MinLength(1)
  @MaxLength(80)
  name?: string;

  @IsString()
  @IsOptional()
  @MaxLength(280)
  description?: string;

  @IsUrl({ require_protocol: true, protocols: ['http', 'https'] })
  @IsOptional()
  @MaxLength(2048)
  avatarUrl?: string;

  @IsString()
  @IsOptional()
  @IsIn(ORDO_ACCENTS, { message: 'accentColor must be a valid accent name' })
  accentColor?: string;

  @IsObject()
  @IsOptional()
  modules?: Record<string, boolean>;
}

export class UpdateMemberDto {
  @IsEnum(['OWNER', 'ADMIN', 'MODERATOR', 'MEMBER', 'GUEST'])
  role!: 'OWNER' | 'ADMIN' | 'MODERATOR' | 'MEMBER' | 'GUEST';
}

export class PinGroupDto {
  @IsBoolean()
  pinned!: boolean;
}
