import { Module } from '@nestjs/common';
import { SyncController } from './controllers/sync.controller';
import { AuthController } from './controllers/auth.controller';
import { BackupsController } from './controllers/backups.controller';

@Module({
  imports: [],
  controllers: [SyncController, AuthController, BackupsController],
  providers: [],
})
export class AppModule {}
