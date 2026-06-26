import {
  Controller,
  Delete,
  Get,
  Param,
  Post,
  Query,
  Res,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { Response } from 'express';
import { MediaService } from './media.service';
import { CurrentUser } from '../common/decorators/current-user.decorator';

@Controller('media')
export class MediaController {
  constructor(private readonly media: MediaService) {}

  @Post()
  @UseInterceptors(FileInterceptor('file', { limits: { fileSize: 10 * 1024 * 1024 } }))
  upload(
    @CurrentUser('id') userId: string,
    @UploadedFile() file: Express.Multer.File,
    @Query('groupId') groupId?: string,
  ) {
    return this.media.store(userId, groupId ?? null, file as any);
  }

  @Get()
  list(@CurrentUser('id') userId: string, @Query('groupId') groupId?: string) {
    return this.media.list(userId, groupId);
  }

  @Get(':id/raw')
  async raw(
    @CurrentUser('id') userId: string,
    @Param('id') id: string,
    @Res({ passthrough: false }) res: Response,
  ) {
    const { absPath, mimeType, filename } = await this.media.rawPath(userId, id);
    res.setHeader('Content-Type', mimeType);
    res.setHeader('Content-Disposition', `inline; filename="${filename.replace(/"/g, '')}"`);
    res.sendFile(absPath);
  }

  @Delete(':id')
  remove(@CurrentUser('id') userId: string, @Param('id') id: string) {
    return this.media.remove(userId, id);
  }
}
