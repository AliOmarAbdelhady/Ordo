import { IsArray, IsInt, IsOptional, IsString, Matches, MaxLength, MinLength } from 'class-validator';

export class UpdateProfileDto {
  @IsString() @IsOptional() @MinLength(1) @MaxLength(80) name?: string;
  @IsString() @IsOptional() @MaxLength(160) bio?: string;
  @IsString() @IsOptional() avatarUrl?: string;
  @IsString() @IsOptional() @Matches(/^[a-z0-9_]{3,20}$/) username?: string;
  @IsString() @IsOptional() timezone?: string;
}

export class UpdatePreferencesDto {
  @IsString() @IsOptional() theme?: string; // light | dark | system
  @IsString() @IsOptional() accentColor?: string;
}

export class UpdateAvailabilityDto {
  @IsString() @IsOptional() timezone?: string;
  @IsString() @IsOptional() workStart?: string;
  @IsString() @IsOptional() workEnd?: string;
  @IsString() @IsOptional() sleepStart?: string;
  @IsString() @IsOptional() sleepEnd?: string;
  @IsArray() @IsInt({ each: true }) @IsOptional() weekdays?: number[];
}
