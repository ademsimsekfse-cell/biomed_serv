import { Controller, Post, UploadedFile, UseInterceptors, Body, Get, Param } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';

@Controller('backups')
export class BackupsController {
  @Post('upload')
  @UseInterceptors(FileInterceptor('file'))
  async upload(@UploadedFile() file: Express.Multer.File, @Body() body: any) {
    // Scaffold: in production you would stream to S3/MinIO and create backup record
    return { status: 'ok', filename: file?.originalname };
  }

  @Get(':id/download')
  async download(@Param('id') id: string) {
    // Scaffold: return a placeholder
    return { status: 'not_implemented', id };
  }
}
