import { IsDateString, IsEnum, IsNumber, IsOptional } from 'class-validator';
import { LocationMode } from '@prisma/client';

export class SetShareDto {
  @IsEnum(LocationMode)
  mode!: LocationMode;

  @IsOptional()
  @IsDateString()
  expiresAt?: string;
}

export class PointDto {
  @IsNumber()
  lat!: number;

  @IsNumber()
  lng!: number;

  @IsOptional()
  @IsNumber()
  accuracy?: number;

  @IsOptional()
  @IsNumber()
  heading?: number;
}
