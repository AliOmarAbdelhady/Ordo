import { TaskPriority, TaskStatus } from '@prisma/client';
import { IsArray, IsDateString, IsEnum, IsInt, IsOptional, IsString, MaxLength, Min } from 'class-validator';

export class CreateTaskDto {
  @IsString() groupId!: string;
  @IsString() @MaxLength(200) title!: string;
  @IsString() @IsOptional() description?: string;
  @IsEnum(TaskPriority) @IsOptional() priority?: TaskPriority;
  @IsEnum(TaskStatus) @IsOptional() status?: TaskStatus;
  @IsDateString() @IsOptional() dueAt?: string;
  @IsArray() @IsString({ each: true }) @IsOptional() assigneeIds?: string[];
}

export class UpdateTaskDto {
  @IsString() @IsOptional() title?: string;
  @IsString() @IsOptional() description?: string;
  @IsEnum(TaskPriority) @IsOptional() priority?: TaskPriority;
  @IsEnum(TaskStatus) @IsOptional() status?: TaskStatus;
  @IsDateString() @IsOptional() dueAt?: string;
  @IsArray() @IsString({ each: true }) @IsOptional() assigneeIds?: string[];
}

export class CreateCommentDto {
  @IsString() @MaxLength(4000) body!: string;
}
