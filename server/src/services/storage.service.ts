import { Injectable } from '@nestjs/common';
import { Client } from 'minio';

@Injectable()
export class StorageService {
  private client: Client;

  constructor() {
    this.client = new Client({
      endPoint: process.env.MINIO_ENDPOINT || 'localhost',
      port: parseInt(process.env.MINIO_PORT || '9000', 10),
      useSSL: false,
      accessKey: process.env.MINIO_ACCESS_KEY || 'minioadmin',
      secretKey: process.env.MINIO_SECRET_KEY || 'minioadmin',
    });
  }

  async ensureBucket(bucket: string) {
    const exists = await this.client.bucketExists(bucket);
    if (!exists) {
      await this.client.makeBucket(bucket);
    }
  }

  async putObject(bucket: string, key: string, buffer: Buffer) {
    await this.ensureBucket(bucket);
    await this.client.putObject(bucket, key, buffer);
  }

  async presignPut(bucket: string, key: string, expiresSeconds = 300) {
    await this.ensureBucket(bucket);
    // returns presigned URL for PUT
    const url = await this.client.presignedPutObject(bucket, key, expiresSeconds);
    return url;
  }

  async getObjectUrl(bucket: string, key: string) {
    // For MinIO local dev, construct url
    const endpoint = process.env.MINIO_ENDPOINT || 'localhost';
    const port = process.env.MINIO_PORT || '9000';
    return `http://${endpoint}:${port}/${bucket}/${key}`;
  }
}
