import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
  OnModuleInit,
} from '@nestjs/common';
import { existsSync, mkdirSync } from 'fs';
import { join, resolve } from 'path';
import { PrismaService } from '../prisma/prisma.service';
import { GroupsService } from '../groups/groups.service';
import { RealtimeGateway } from '../realtime/realtime.gateway';

export const MAX_UPLOAD_BYTES = 10 * 1024 * 1024; // 10 MB

export const ALLOWED_MIME = new Set([
  'image/png',
  'image/jpeg',
  'image/webp',
  'image/gif',
  'application/pdf',
  'text/plain',
  'application/json',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'application/vnd.ms-excel',
  'application/msword',
]);

export function uploadsRoot(): string {
  return resolve(process.env.UPLOADS_DIR ?? join(process.cwd(), 'uploads'));
}

export function extFor(mimeType: string): string {
  const map: Record<string, string> = {
    'image/png': 'png',
    'image/jpeg': 'jpg',
    'image/webp': 'webp',
    'image/gif': 'gif',
    'application/pdf': 'pdf',
    'text/plain': 'txt',
    'application/json': 'json',
  };
  return map[mimeType] ?? 'bin';
}

const EXT_TO_MIME: Record<string, string> = {
  png: 'image/png',
  jpg: 'image/jpeg',
  jpeg: 'image/jpeg',
  webp: 'image/webp',
  gif: 'image/gif',
  pdf: 'application/pdf',
  txt: 'text/plain',
  json: 'application/json',
  docx: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  xlsx: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  doc: 'application/msword',
  xls: 'application/vnd.ms-excel',
};

/**
 * Clients (notably mobile file pickers) often report application/octet-stream.
 * Infer a precise MIME from the filename extension so validation + serving use
 * the correct type. Falls back to the reported mime when unknown.
 */
export function mimeForFilename(filename: string, reported: string): string {
  if (reported && reported !== 'application/octet-stream') return reported;
  const ext = filename.toLowerCase().split('.').pop() ?? '';
  return EXT_TO_MIME[ext] ?? reported ?? 'application/octet-stream';
}

export interface UploadedFile {
  originalname: string;
  mimetype: string;
  size: number;
  buffer: Buffer;
}

@Injectable()
export class MediaService implements OnModuleInit {
  constructor(
    private readonly prisma: PrismaService,
    private readonly groups: GroupsService,
    private readonly realtime: RealtimeGateway,
  ) {}

  onModuleInit() {
    const root = uploadsRoot();
    if (!existsSync(root)) mkdirSync(root, { recursive: true });
  }

  validate(file: UploadedFile | undefined): UploadedFile {
    if (!file) throw new BadRequestException('No file provided');
    if (file.size > MAX_UPLOAD_BYTES) throw new BadRequestException('File too large (max 10MB)');
    if (!ALLOWED_MIME.has(file.mimetype)) throw new BadRequestException('Unsupported file type');
    return file;
  }

  async store(userId: string, groupId: string | null, file: UploadedFile) {
    if (groupId) await this.groups.requireMember(groupId, userId);
    // Normalize the reported MIME (mobile pickers often send octet-stream).
    const mimeType = mimeForFilename(file.originalname, file.mimetype);
    const normalized: UploadedFile = { ...file, mimetype: mimeType };
    this.validate(normalized);

    const crypto = await import('crypto');
    const id = crypto.randomUUID();
    const storageKey = `${id}.${extFor(mimeType)}`;
    const { writeFile } = await import('fs/promises');
    await writeFile(join(uploadsRoot(), storageKey), file.buffer);

    const media = await this.prisma.mediaFile.create({
      data: {
        id,
        groupId,
        uploaderId: userId,
        filename: file.originalname.slice(0, 255),
        mimeType,
        sizeBytes: file.size,
        storageKey,
        url: `/api/media/${id}/raw`,
      },
    });

    if (groupId) this.realtime.emitToGroup(groupId, 'media:created', this.toDto(media));
    return this.toDto(media);
  }

  async list(userId: string, groupId?: string) {
    if (groupId) {
      await this.groups.requireMember(groupId, userId);
      const items = await this.prisma.mediaFile.findMany({
        where: { groupId },
        orderBy: { createdAt: 'desc' },
        take: 100,
        include: { uploader: { select: { id: true, name: true, avatarUrl: true } } },
      });
      return { files: items.map((i) => this.toDto(i)) };
    }
    // No-group list = the caller's own uploads. The previous `{ groupId: null }`
    // clause matched EVERY user's personal uploads (an IDOR); only own files here.
    const items = await this.prisma.mediaFile.findMany({
      where: { uploaderId: userId },
      orderBy: { createdAt: 'desc' },
      take: 100,
      include: { uploader: { select: { id: true, name: true, avatarUrl: true } } },
    });
    return { files: items.map((i) => this.toDto(i)) };
  }

  async assertReadable(userId: string, id: string) {
    const media = await this.prisma.mediaFile.findUnique({ where: { id } });
    if (!media) throw new NotFoundException('File not found');
    if (media.uploaderId !== userId) {
      if (media.groupId) await this.groups.requireMember(media.groupId, userId);
      else throw new ForbiddenException('Not allowed to access this file');
    }
    return media;
  }

  async rawPath(userId: string, id: string): Promise<{ absPath: string; mimeType: string; filename: string }> {
    const media = await this.assertReadable(userId, id);
    const absPath = join(uploadsRoot(), media.storageKey);
    if (!existsSync(absPath)) throw new NotFoundException('File missing on disk');
    return { absPath, mimeType: media.mimeType, filename: media.filename };
  }

  async remove(userId: string, id: string) {
    const media = await this.prisma.mediaFile.findUnique({ where: { id } });
    if (!media) throw new NotFoundException('File not found');
    if (media.uploaderId !== userId) {
      if (media.groupId) await this.groups.requirePermission(media.groupId, userId, 'FILE_DELETE_ANY');
      else throw new ForbiddenException('Not allowed to delete this file');
    }
    const absPath = join(uploadsRoot(), media.storageKey);
    const { unlink } = await import('fs/promises');
    await unlink(absPath).catch(() => undefined);
    await this.prisma.mediaFile.delete({ where: { id } });
    if (media.groupId) this.realtime.emitToGroup(media.groupId, 'media:deleted', { id });
    return { ok: true };
  }

  private toDto(m: any) {
    return {
      id: m.id,
      groupId: m.groupId,
      uploader: m.uploader ?? { id: m.uploaderId },
      filename: m.filename,
      mimeType: m.mimeType,
      sizeBytes: m.sizeBytes,
      url: m.url,
      isImage: m.mimeType?.startsWith('image/'),
      createdAt: new Date(m.createdAt).toISOString(),
    };
  }
}
