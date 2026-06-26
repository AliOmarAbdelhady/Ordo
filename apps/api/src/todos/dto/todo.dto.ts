import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsDateString,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
} from 'class-validator';

export class CreateTodoDto {
  @IsString()
  @MaxLength(300)
  title!: string;

  @IsString()
  @IsOptional()
  @MaxLength(4000)
  note?: string;

  @IsUUID()
  @IsOptional()
  groupId?: string;

  @IsDateString()
  @IsOptional()
  dueAt?: string;

  @IsArray()
  @IsString({ each: true })
  @ArrayMaxSize(20)
  @MaxLength(40, { each: true })
  @IsOptional()
  labels?: string[];
}

export class UpdateTodoDto {
  @IsString()
  @IsOptional()
  @MaxLength(300)
  title?: string;

  @IsString()
  @IsOptional()
  @MaxLength(4000)
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
  @ArrayMaxSize(20)
  @MaxLength(40, { each: true })
  @IsOptional()
  labels?: string[];
}

export class ReorderDto {
  @IsArray()
  @IsString({ each: true })
  @ArrayMaxSize(500)
  ids!: string[];
}
