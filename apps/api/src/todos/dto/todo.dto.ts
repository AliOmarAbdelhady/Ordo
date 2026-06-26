import {
  IsArray,
  IsBoolean,
  IsDateString,
  IsInt,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';

export class CreateTodoDto {
  @IsString()
  @MaxLength(300)
  title!: string;

  @IsString()
  @IsOptional()
  note?: string;

  @IsString()
  @IsOptional()
  groupId?: string;

  @IsDateString()
  @IsOptional()
  dueAt?: string;

  @IsArray()
  @IsString({ each: true })
  @IsOptional()
  labels?: string[];
}

export class UpdateTodoDto {
  @IsString()
  @IsOptional()
  title?: string;

  @IsString()
  @IsOptional()
  note?: string;

  @IsBoolean()
  @IsOptional()
  done?: boolean;

  @IsDateString()
  @IsOptional()
  dueAt?: string | null;

  @IsInt()
  @IsOptional()
  order?: number;

  @IsArray()
  @IsString({ each: true })
  @IsOptional()
  labels?: string[];
}

export class ReorderDto {
  @IsArray()
  @IsString({ each: true })
  ids!: string[];
}
