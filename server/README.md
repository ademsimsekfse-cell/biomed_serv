### Server: Auth Guard and Protected Endpoints

I added a simple AuthGuard (server/src/guards/auth.guard.ts) and applied it to the sync and backups controllers.

- Development mode accepts `fake_access_token_for_dev` or any token and attaches a `req.user` stub.
- Production mode requires the token to equal `JWT_SECRET` (placeholder). Replace with real JWT validation.

### How to call protected endpoints during development

Use the following Authorization header for testing:

  Authorization: Bearer fake_access_token_for_dev

Example curl (sync push):

```bash
curl -X POST http://localhost:3000/sync/push \
  -H "Authorization: Bearer fake_access_token_for_dev" \
  -H "Content-Type: application/json" \
  -d '{"client_id":"device-123","changes":[{"local_op_id":"op-1","entity_type":"service_form","entity_id":null,"op_type":"create","data":{"title":"test"},"client_ts":"2026-07-10T10:00:00Z"}] }'
```

### Next steps (already queued)
- Hook ServiceForm create/update flows to enqueue change into Outbox (client-side) and call OutboxSyncWorker.start() during app init so queue is processed automatically when online.
- Implement real JWT auth and token refresh in production.
