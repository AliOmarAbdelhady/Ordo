import { ArrayMaxSize, IsArray, IsObject, IsOptional, IsString, IsUUID, MaxLength, MinLength } from 'class-validator';

export class ParseCommandDto {
  @IsString()
  @MinLength(1)
  @MaxLength(4000)
  text!: string;

  @IsUUID()
  @IsOptional()
  groupId?: string;
}

export class ExtractTasksDto {
  @IsArray()
  @ArrayMaxSize(100)
  @IsString({ each: true })
  @MaxLength(2000, { each: true })
  messages!: string[];

  @IsUUID()
  @IsOptional()
  groupId?: string;
}

export class ApplySuggestionDto {
  /**
   * The structured suggestion to apply. Shape varies per intent, so this is
   * validated field-by-field in AiService.apply() (intent whitelist, required
   * fields, type/length checks) before dispatch. @IsObject keeps the property
   * alive under the global whitelist ValidationPipe.
   */
  @IsObject()
  suggestion!: any;

  @IsUUID()
  @IsOptional()
  groupId?: string;
}

export class SummarizeGroupDto {
  @IsUUID()
  groupId!: string;
}
