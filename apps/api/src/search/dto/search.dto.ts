import { IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

export class SearchQueryDto {
  @IsString()
  @IsOptional()
  @MinLength(2)
  @MaxLength(100)
  q?: string;
}
