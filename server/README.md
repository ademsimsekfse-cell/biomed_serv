# Biomed Serv API (NestJS scaffold)

This directory contains a minimal NestJS scaffold for the Biomed Serv REST API used for sync and backups.

Quick start (local - requires Docker):

1. Copy `.env.example` to `.env` and set values.
2. Start services:
   ```bash
   docker-compose up --build
   ```
3. API will be available at http://localhost:3000 and Swagger at http://localhost:3000/docs

This scaffold includes:
- Basic NestJS app skeleton
- /sync and /auth controllers (minimal)
- docker-compose with Postgres and MinIO for local testing

Next steps:
- Implement DB models, auth, and robust sync logic
- Add OpenAPI details and tests
