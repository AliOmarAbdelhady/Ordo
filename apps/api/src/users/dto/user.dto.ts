import { ArrayMaxSize, IsArray, IsEnum, IsIn, IsInt, IsOptional, IsString, IsUrl, Matches, Max, MaxLength, Min, MinLength } from 'class-validator';

const IANA_TZ = /^[A-Za-z0-9_+-]+(\/[A-Za-z0-9_+-]+)*$/;
// accentColor is a NAMED token (matches Flutter OrdoAccent + seed data), not hex.
const ORDO_ACCENTS = ['blue', 'rose', 'emerald', 'violet', 'amber', 'orange', 'cyan', 'slate'] as const;
const HHMM = /^([01]?\d|2[0-3]):[0-5]\d$/;

export class UpdateProfileDto {
  @IsString() @IsOptional() @MinLength(1) @MaxLength(80) name?: string;
  @IsString() @IsOptional() @MaxLength(160) bio?: string;
  @IsUrl({ require_protocol: true, protocols: ['http', 'https'] }) @IsOptional() @MaxLength(2048) avatarUrl?: string;
  @IsString() @IsOptional() @Matches(/^[a-z0-9_]{3,20}$/) username?: string;
  @IsString() @IsOptional() @Matches(IANA_TZ, { message: 'timezone must be a valid IANA zone' }) @MaxLength(64) timezone?: string;
}

export class UpdatePreferencesDto {
  @IsEnum(['light', 'dark', 'system']) @IsOptional() theme?: string;
  @IsIn(ORDO_ACCENTS, { message: 'accentColor must be a valid accent name' }) @IsOptional() accentColor?: string;
}

export class UpdateAvailabilityDto {
  @IsString() @IsOptional() @Matches(IANA_TZ, { message: 'timezone must be a valid IANA zone' }) @MaxLength(64) timezone?: string;
  @IsString() @IsOptional() @Matches(HHMM, { message: 'workStart must be HH:mm' }) workStart?: string;
  @IsString() @IsOptional() @Matches(HHMM, { message: 'workEnd must be HH:mm' }) workEnd?: string;
  @IsString() @IsOptional() @Matches(HHMM, { message: 'sleepStart must be HH:mm' }) sleepStart?: string;
  @IsString() @IsOptional() @Matches(HHMM, { message: 'sleepEnd must be HH:mm' }) sleepEnd?: string;
  // weekdays: 0=Sun..6=Sat (schema/slots convention)
  @IsArray() @ArrayMaxSize(7) @IsInt({ each: true }) @Min(0, { each: true }) @Max(6, { each: true }) @IsOptional() weekdays?: number[];
}
