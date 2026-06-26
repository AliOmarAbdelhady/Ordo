import { Type } from 'class-transformer';
import {
  IsArray,
  IsDateString,
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  Min,
  ValidateNested,
} from 'class-validator';

export class GroupAvailabilityStripDto {
  @IsDateString()
  @IsOptional()
  from?: string;

  @IsDateString()
  @IsOptional()
  to?: string;
}

export class FindSlotsDto {
  @IsString()
  groupId!: string;

  @IsDateString()
  dateRangeStart!: string;

  @IsDateString()
  dateRangeEnd!: string;

  @IsInt()
  @Min(5)
  durationMinutes!: number;

  @IsArray()
  @IsString({ each: true })
  @IsOptional()
  requiredMemberIds?: string[];

  @IsArray()
  @IsString({ each: true })
  @IsOptional()
  optionalMemberIds?: string[];

  @IsInt()
  @Min(1)
  @IsOptional()
  minimumAvailableCount?: number;

  @IsArray()
  @IsEnum(['morning', 'afternoon', 'evening', 'night'], { each: true })
  @IsOptional()
  preferredTimeWindows?: ('morning' | 'afternoon' | 'evening' | 'night')[];

  @IsString()
  @IsOptional()
  timezone?: string;
}
