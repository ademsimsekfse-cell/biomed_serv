import { Injectable, CanActivate, ExecutionContext, UnauthorizedException } from '@nestjs/common';

@Injectable()
export class AuthGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    const req = context.switchToHttp().getRequest();
    const authHeader = req.headers['authorization'] || req.headers['Authorization'];

    if (!authHeader || typeof authHeader !== 'string' || !authHeader.startsWith('Bearer ')) {
      throw new UnauthorizedException('Missing Authorization token');
    }

    const token = authHeader.split(' ')[1];

    // Development: accept fake token for convenience
    if (process.env.NODE_ENV === 'development') {
      if (token === 'fake_access_token_for_dev' || token === process.env.JWT_SECRET) {
        req.user = { id: 'dev-user' };
        return true;
      }
      // In dev accept any token but tag user as dev
      req.user = { id: 'dev-' + token.substring(0, 6) };
      return true;
    }

    // Production: simple equality check against JWT_SECRET (placeholder)
    if (!process.env.JWT_SECRET || token !== process.env.JWT_SECRET) {
      throw new UnauthorizedException('Invalid token');
    }

    req.user = { id: 'server' };
    return true;
  }
}
