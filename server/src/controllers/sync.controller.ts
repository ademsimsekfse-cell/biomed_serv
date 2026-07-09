import { Controller, Post, Body, Get, Query, Headers, UnauthorizedException } from '@nestjs/common';

@Controller('sync')
export class SyncController {
  @Post('push')
  async push(@Headers('authorization') auth: string, @Body() body: any) {
    // For scaffold: accept changes and echo applied status
    // In production: validate token, persist change_logs, apply transactions
    const applied = (body.changes || []).map((c: any) => ({
      local_op_id: c.local_op_id,
      server_id: `srv-${Math.random().toString(36).substring(2,9)}`,
      status: 'applied',
      server_ts: new Date().toISOString(),
    }));

    return {
      server_ts_now: new Date().toISOString(),
      applied,
    };
  }

  @Get('pull')
  async pull(@Query('since') since: string) {
    // Scaffold: return empty changes
    return {
      server_ts_now: new Date().toISOString(),
      changes: [],
    };
  }
}
