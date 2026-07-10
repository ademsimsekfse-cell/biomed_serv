import { Controller, Post, UploadedFile, UseInterceptors, Body, Get, Param, BadRequestException } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { StorageService } from '../services/storage.service';

@Controller('backups')
export class BackupsController {
  constructor(private readonly storage: StorageService) {}

  @Post('upload')
  @UseInterceptors(FileInterceptor('file'))
  async upload(@UploadedFile() file: Express.Multer.File, @Body() body: any) {
    if (!file) throw new BadRequestException('No file uploaded');
    // Store object into MinIO synchronously (for scaffold)
    const bucket = process.env.MINIO_BUCKET || 'biomed-backups';
    const key = `backups/${Date.now()}_${file.originalname}`;
    await this.storage.putObject(bucket, key, file.buffer);
    const url = await this.storage.getObjectUrl(bucket, key);
    return { status: 'ok', filename: file.originalname, url };
  }

  @Get('presign')
  async presign(@Body() body: any) {
    // Body: { filename }
    const filename = body?.filename;
    if (!filename) throw new BadRequestException('filename required');
    const bucket = process.env.MINIO_BUCKET || 'biomed-backups';
    const key = `backups/${Date.now()}_${filename}`;
    const presigned = await this.storage.presignPut(bucket, key, 60 * 5); // 5 minutes
    return { url: presigned, key };
  }

  @Get(':id/download')
  async download(@Param('id') id: string) {
    // Scaffold: return a placeholder
    return { status: 'not_implemented', id };
  }
}
