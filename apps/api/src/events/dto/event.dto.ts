import { IsEnum } from 'class-validator';
import { RsvpStatus } from '@prisma/client';

export class RsvpDto {
  @IsEnum(RsvpStatus)
  status!: RsvpStatus;
}
