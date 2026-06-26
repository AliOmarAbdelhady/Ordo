import { BlockFlexibility, Visibility } from '@prisma/client';
import { Type } from 'class-transformer';
import {
  IsArray,
  IsBoolean,
  IsDateString,
  IsEnum,
  IsInt,
  IsObject,
  IsOptional,
  IsString,
  Min,
  ValidateNested,
} from 'class-validator';

export class CreateBlockDto {
  @IsString()
  title!: string;

  @IsString()
  @IsOptional()
  description?: string;

  @IsDateString()
  startTime!: string;

  @IsDateString()
  endTime!: string;

  @IsBoolean()
  @IsOptional()
  allDay?: boolean;

  @IsString()
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
  color?: string;

  @IsString()
  @IsOptional()
  location?: string;

  @IsString()
  @IsOptional()
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
  timezone?: string;
}

export class UpdateBlockDto {
  @IsString() @IsOptional() title?: string;
  @IsString() @IsOptional() description?: string;
  @IsDateString() @IsOptional() startTime?: string;
  @IsDateString() @IsOptional() endTime?: string;
  @IsBoolean() @IsOptional() allDay?: boolean;
  @IsEnum(Visibility) @IsOptional() visibility?: Visibility;
  @IsEnum(BlockFlexibility) @IsOptional() flexibility?: BlockFlexibility;
  @IsString() @IsOptional() color?: string;
  @IsString() @IsOptional() location?: string;
  @IsString() @IsOptional() recurrenceRule?: string;
  @IsInt() @Min(0) @IsOptional() reminderMinutesBefore?: number;
  @IsBoolean() @IsOptional() isEvent?: boolean;
}

export class SyncEntryDto {
  @IsString() groupId!: string;
  @IsEnum(Visibility) visibility!: Visibility;
}

export class SyncBlocksDto {
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => SyncEntryDto)
  syncs!: SyncEntryDto[];
}
