import { GroupType } from '@prisma/client';
import { IsBoolean, IsEnum, IsObject, IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

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

  @IsString()
  @IsOptional()
  avatarUrl?: string;

  @IsString()
  @IsOptional()
  accentColor?: string;

  @IsObject()
  @IsOptional()
  modules?: Record<string, boolean>;
}

export class UpdateGroupDto {
  @IsString()
  @IsOptional()
  name?: string;

  @IsString()
  @IsOptional()
  description?: string;

  @IsString()
  @IsOptional()
  avatarUrl?: string;

  @IsString()
  @IsOptional()
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
