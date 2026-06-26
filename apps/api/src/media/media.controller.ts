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
    const safeName = filename.replace(/"/g, '');
    res.setHeader('Content-Type', mimeType);
    // Prevent MIME sniffing of user-uploaded content served from our origin.
    res.setHeader('X-Content-Type-Options', 'nosniff');
    // Serve images inline; force download for everything else so a polyglot
    // upload (e.g. HTML masquerading as an image) is not rendered in our origin.
    const isImage = mimeType.startsWith('image/');
    res.setHeader('Content-Disposition', `${isImage ? 'inline' : 'attachment'}; filename="${safeName}"`);
    res.sendFile(absPath);
  }

  @Delete(':id')
  remove(@CurrentUser('id') userId: string, @Param('id') id: string) {
    return this.media.remove(userId, id);
  }
}
