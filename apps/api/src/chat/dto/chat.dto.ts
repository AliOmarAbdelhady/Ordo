import { IsInt, IsOptional, IsString, Max, MaxLength, Min } from 'class-validator';

export class CreateMessageDto {
  @IsString()
  @MaxLength(4000)
  body!: string;

  @IsString()
  @IsOptional()
  replyToId?: string;
}

export class EditMessageDto {
  @IsString()
  @MaxLength(4000)
  body!: string;
}

export class ReactDto {
  @IsString()
  emoji!: string;
}

export class ListMessagesDto {
  @IsString()
  @IsOptional()
  before?: string; // ISO date cursor

  @IsInt()
  @Min(1)
  @Max(100)
  @IsOptional()
  limit?: number;
}
