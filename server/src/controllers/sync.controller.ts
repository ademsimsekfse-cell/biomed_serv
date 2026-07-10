import { Controller, Post, Body, Get, Query } from '@nestjs/common';
import { DbService } from '../services/db.service';
import { UseGuards } from '@nestjs/common';
import { AuthGuard } from '../guards/auth.guard';

@UseGuards(AuthGuard)
@Controller('sync')
export class SyncController {
  constructor(private readonly db: DbService) {}

  @Post('push')
  async push(@Body() body: any) {
    const clientId = body.client_id || null;
    const changes = body.changes || [];
    const applied = [] as any[];

    for (const c of changes) {
      // Persist change into change_logs
      const changeRecord = {
        entity_type: c.entity_type || c.type || 'unknown',
        entity_id: c.entity_id ?? null,
        op_type: c.op_type || c.op || 'update',
        data: c.data ?? c.payload ?? null,
        client_timestamp: c.client_ts || c.client_timestamp || null,
        client_id: clientId,
      };
      const inserted = await this.db.insertChangeLog(changeRecord);
      applied.push({
        local_op_id: c.local_op_id ?? null,
        server_id: `change-${inserted.id}`,
        status: 'applied',
        server_ts: new Date().toISOString(),
      });
    }

    return {
      server_ts_now: new Date().toISOString(),
      applied,
    };
  }

  @Get('pull')
  async pull(@Query('since') since: string) {
    // For now, return empty changes. Later this should query change_logs since the timestamp
    return {
      server_ts_now: new Date().toISOString(),
      changes: [],
    };
  }
}
