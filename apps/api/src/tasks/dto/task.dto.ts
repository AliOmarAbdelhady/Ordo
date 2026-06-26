import { TaskPriority, TaskStatus } from '@prisma/client';
import { ArrayMaxSize, IsArray, IsDateString, IsEnum, IsInt, IsOptional, IsString, IsUUID, MaxLength, Min } from 'class-validator';

export class CreateTaskDto {
  @IsUUID() groupId!: string;
  @IsString() @MaxLength(200) title!: string;
  @IsString() @IsOptional() @MaxLength(8000) description?: string;
  @IsEnum(TaskPriority) @IsOptional() priority?: TaskPriority;
  @IsEnum(TaskStatus) @IsOptional() status?: TaskStatus;
  @IsDateString() @IsOptional() dueAt?: string;
  @IsArray() @ArrayMaxSize(50) @IsUUID('4', { each: true }) @IsOptional() assigneeIds?: string[];
}

export class UpdateTaskDto {
  @IsString() @IsOptional() @MaxLength(200) title?: string;
  @IsString() @IsOptional() @MaxLength(8000) description?: string;
  @IsEnum(TaskPriority) @IsOptional() priority?: TaskPriority;
  @IsEnum(TaskStatus) @IsOptional() status?: TaskStatus;
  @IsDateString() @IsOptional() dueAt?: string;
  @IsArray() @ArrayMaxSize(50) @IsUUID('4', { each: true }) @IsOptional() assigneeIds?: string[];
}

export class CreateCommentDto {
  @IsString() @MaxLength(4000) body!: string;
}
