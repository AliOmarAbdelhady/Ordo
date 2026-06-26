import { IsArray, IsObject, IsOptional, IsString, MinLength } from 'class-validator';

export class ParseCommandDto {
  @IsString()
  @MinLength(1)
  text!: string;

  @IsString()
  @IsOptional()
  groupId?: string;
}

export class ExtractTasksDto {
  @IsArray()
  @IsString({ each: true })
  messages!: string[];

  @IsString()
  @IsOptional()
  groupId?: string;
}

export class ApplySuggestionDto {
  /**
   * The structured suggestion to apply. Shape varies per intent — the service
   * validates intent + required fields. @IsObject keeps this property alive
   * under the global whitelist ValidationPipe.
   */
  @IsObject()
  suggestion!: any;

  @IsString()
  @IsOptional()
  groupId?: string;
}
