import { Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import {
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  OnGatewayDisconnect,
  OnGatewayInit,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import { MemberStatus } from '@prisma/client';
import { Server, Socket } from 'socket.io';
import { PrismaService } from '../prisma/prisma.service';

interface SocketData {
  userId?: string;
}

// Mirror the HTTP CORS hardening in main.ts: an explicit allowlist enables
// credentials; '*' reflects the origin WITHOUT credentials (the API uses Bearer
// tokens, not cookies); unset falls back to the dev origin. Never combine a
// reflected wildcard with credentials.
const _corsList = (process.env.CORS_ORIGIN ?? '').split(',').map((s) => s.trim()).filter(Boolean);
const _corsWildcard = _corsList.includes('*');
const GATEWAY_CORS = {
  origin: _corsWildcard ? true : _corsList.length ? _corsList : 'http://localhost:3000',
  credentials: !_corsWildcard,
};

@WebSocketGateway({ cors: GATEWAY_CORS })
export class RealtimeGateway
  implements OnGatewayInit, OnGatewayConnection, OnGatewayDisconnect
{
  @WebSocketServer() server!: Server;
  private readonly logger = new Logger('Realtime');

  constructor(
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
    private readonly prisma: PrismaService,
  ) {}

  afterInit() {
    this.logger.log('WebSocket server ready');
  }

  async handleConnection(client: Socket) {
    try {
      const raw: string =
        (client.handshake.auth?.token as string) ||
        (client.handshake.headers?.authorization as string) ||
        '';
      const token = raw.replace(/^Bearer\s+/i, '');
      const payload = await this.jwt.verifyAsync<{ sub: string }>(token, {
        secret: this.config.get<string>('JWT_ACCESS_SECRET'),
      });
      const userId = payload.sub;
      (client.data as SocketData).userId = userId;

      await client.join(`user:${userId}`);
      const memberships = await this.prisma.groupMember.findMany({
        where: { userId, status: MemberStatus.ACTIVE },
        select: { groupId: true },
      });
      for (const m of memberships) await client.join(`group:${m.groupId}`);

      this.logger.log(`✔ connected ${userId} (${client.id})`);
    } catch {
      this.logger.warn(`Rejecting socket ${client.id} — invalid auth`);
      client.disconnect();
    }
  }

  handleDisconnect(client: Socket) {
    const userId = (client.data as SocketData).userId;
    if (userId) this.logger.log(`✖ disconnected ${userId} (${client.id})`);
  }

  /** Chat room join when a user opens a group chat. */
  @SubscribeMessage('chat:typing')
  onTyping(@ConnectedSocket() client: Socket, @MessageBody() body: { groupId: string; isTyping: boolean }) {
    const userId = (client.data as SocketData).userId;
    if (!userId || !body?.groupId) return;
    // Only broadcast if this socket is actually in the target group's room.
    // Rooms are populated from the user's ACTIVE memberships at connection, so
    // this stops a client from emitting typing into a group it isn't a member of.
    if (!client.rooms.has(`group:${body.groupId}`)) return;
    client.to(`group:${body.groupId}`).emit('chat:typing', { groupId: body.groupId, userId, isTyping: body.isTyping });
  }

  // ── Helpers used by other modules to push events ──────────────────────────
  emitToUser(userId: string, event: string, payload: unknown) {
    this.server?.to(`user:${userId}`).emit(event, payload);
  }

  emitToGroup(groupId: string, event: string, payload: unknown) {
    this.server?.to(`group:${groupId}`).emit(event, payload);
  }

  emitToAll(event: string, payload: unknown) {
    this.server?.emit(event, payload);
  }
}
