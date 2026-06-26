import { IsDateString, IsNumber, IsOptional, IsString } from 'class-validator';
import { LocationMode } from '@prisma/client';

export class SetShareDto {
  @IsString()
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
