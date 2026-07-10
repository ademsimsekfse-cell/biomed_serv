import { Injectable, OnModuleInit, Logger } from '@nestjs/common';
import { Pool } from 'pg';

@Injectable()
export class DbService implements OnModuleInit {
  private pool: Pool;
  private readonly logger = new Logger(DbService.name);

  constructor() {
    this.pool = new Pool({
      host: process.env.POSTGRES_HOST || 'localhost',
      port: parseInt(process.env.POSTGRES_PORT || '5432', 10),
      database: process.env.POSTGRES_DB || 'biomed',
      user: process.env.POSTGRES_USER || 'biomed',
      password: process.env.POSTGRES_PASSWORD || 'biomed',
    });
  }

  async onModuleInit() {
    this.logger.log('Connecting to Postgres...');
    await this.ensureTables();
    this.logger.log('Postgres ready');
  }

  async ensureTables() {
    const client = await this.pool.connect();
    try {
      await client.query(`
        CREATE TABLE IF NOT EXISTS change_logs (
          id SERIAL PRIMARY KEY,
          entity_type TEXT NOT NULL,
          entity_id TEXT,
          op_type TEXT NOT NULL,
          data JSONB,
          client_timestamp TIMESTAMPTZ,
          server_timestamp TIMESTAMPTZ DEFAULT now(),
          client_id TEXT
        );
      `);
    } finally {
      client.release();
    }
  }

  async insertChangeLog(change: any) {
    const { entity_type, entity_id, op_type, data, client_timestamp, client_id } = change;
    const res = await this.pool.query(
      `INSERT INTO change_logs(entity_type, entity_id, op_type, data, client_timestamp, client_id) VALUES($1,$2,$3,$4,$5,$6) RETURNING id`,
      [entity_type, entity_id, op_type, data, client_timestamp ? new Date(client_timestamp) : null, client_id]
    );
    return res.rows[0];
  }
}
