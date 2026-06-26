import { Type } from 'class-transformer';
import { ArrayMinSize, ArrayUnique, IsArray, IsBoolean, IsDateString, IsInt, IsOptional, IsString, MaxLength, MinLength, ValidateNested } from 'class-validator';

export class PollOptionDto {
  @IsString()
  @MinLength(1)
  @MaxLength(120)
  text!: string;
}

export class CreatePollDto {
  @IsString()
  @MinLength(2)
  @MaxLength(200)
  question!: string;

  @IsArray()
  @ArrayMinSize(2)
  @ArrayUnique((o: PollOptionDto) => o.text)
  @ValidateNested({ each: true })
  @Type(() => PollOptionDto)
  options!: PollOptionDto[];

  @IsBoolean()
  @IsOptional()
  multiple?: boolean;

  @IsDateString()
  @IsOptional()
  closesAt?: string;
}

export class VoteDto {
  @IsArray()
  @ArrayMinSize(1)
  @IsString({ each: true })
  optionIds!: string[];
}
