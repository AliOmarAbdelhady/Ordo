import { IsOptional, IsString, IsUUID, Matches, MaxLength, MinLength } from 'class-validator';

const HEX_COLOR = /^#([0-9A-Fa-f]{3}|[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$/;

export class CreateCategoryDto {
  @IsString()
  @MinLength(1)
  @MaxLength(60)
  name!: string;

  @IsString()
  @IsOptional()
  @Matches(HEX_COLOR, { message: 'color must be a hex color like #2563EB' })
  color?: string;

  @IsUUID()
  @IsOptional()
  groupId?: string;
}
