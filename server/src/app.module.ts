import { Module } from '@nestjs/common';
import { SyncController } from './controllers/sync.controller';
import { AuthController } from './controllers/auth.controller';
import { BackupsController } from './controllers/backups.controller';
import { DbService } from './services/db.service';
import { StorageService } from './services/storage.service';

@Module({
  imports: [],
  controllers: [SyncController, AuthController, BackupsController],
  providers: [DbService, StorageService],
})
export class AppModule {}
