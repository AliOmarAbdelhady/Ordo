import { BlockFlexibility, Visibility } from '@prisma/client';
import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsDateString,
  IsEnum,
  IsInt,
  IsObject,
  IsOptional,
  IsString,
  IsUUID,
  Matches,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';

const HEX_COLOR = /^#([0-9A-Fa-f]{3}|[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$/;
const IANA_TZ = /^[A-Za-z0-9_+-]+(\/[A-Za-z0-9_+-]+)*$/;

export class CreateBlockDto {
  @IsString()
  @MaxLength(120)
  title!: string;

  @IsString()
  @IsOptional()
  @MaxLength(4000)
  description?: string;

  @IsDateString()
  startTime!: string;

  @IsDateString()
  endTime!: string;

  @IsBoolean()
  @IsOptional()
  allDay?: boolean;

  @IsUUID()
  @IsOptional()
  groupId?: string;

  @IsEnum(Visibility)
  @IsOptional()
  visibility?: Visibility;

  @IsEnum(BlockFlexibility)
  @IsOptional()
  flexibility?: BlockFlexibility;

  @IsString()
  @IsOptional()
  @Matches(HEX_COLOR, { message: 'color must be a hex color like #2563EB' })
  color?: string;

  @IsString()
  @IsOptional()
  @MaxLength(200)
  location?: string;

  @IsString()
  @IsOptional()
  @MaxLength(200)
  recurrenceRule?: string;

  @IsInt()
  @Min(0)
  @IsOptional()
  reminderMinutesBefore?: number;

  @IsBoolean()
  @IsOptional()
  isEvent?: boolean;

  @IsString()
  @IsOptional()
  @Matches(IANA_TZ, { message: 'timezone must be a valid IANA zone' })
  timezone?: string;
}

export class UpdateBlockDto {
  @IsString() @IsOptional() @MaxLength(120) title?: string;
  @IsString() @IsOptional() @MaxLength(4000) description?: string;
  @IsDateString() @IsOptional() startTime?: string;
  @IsDateString() @IsOptional() endTime?: string;
  @IsBoolean() @IsOptional() allDay?: boolean;
  @IsEnum(Visibility) @IsOptional() visibility?: Visibility;
  @IsEnum(BlockFlexibility) @IsOptional() flexibility?: BlockFlexibility;
  @IsString() @IsOptional() @Matches(HEX_COLOR, { message: 'color must be a hex color like #2563EB' }) color?: string;
  @IsString() @IsOptional() @MaxLength(200) location?: string;
  @IsString() @IsOptional() @MaxLength(200) recurrenceRule?: string;
  @IsInt() @Min(0) @IsOptional() reminderMinutesBefore?: number;
  @IsBoolean() @IsOptional() isEvent?: boolean;
}

export class SyncEntryDto {
  @IsUUID() groupId!: string;
  @IsEnum(Visibility) visibility!: Visibility;
}

export class SyncBlocksDto {
  @IsArray()
  @ArrayMaxSize(50)
  @ValidateNested({ each: true })
  @Type(() => SyncEntryDto)
  syncs!: SyncEntryDto[];
}

/** Query params for the timeline range endpoints. */
export class TimelineRangeDto {
  @IsDateString()
  @IsOptional()
  from?: string;

  @IsDateString()
  @IsOptional()
  to?: string;
}
