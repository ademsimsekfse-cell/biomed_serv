import { Controller, Post, Body } from '@nestjs/common';

@Controller('auth')
export class AuthController {
  @Post('login')
  login(@Body() body: any) {
    // Minimal stub: return fake token for testing
    return {
      access_token: 'fake_access_token_for_dev',
      refresh_token: 'fake_refresh_token',
      expires_in: 900,
    };
  }
}
