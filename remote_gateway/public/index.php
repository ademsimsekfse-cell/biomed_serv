<?php
declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');
header('X-Content-Type-Options: nosniff');

$configPath = dirname(__DIR__) . '/config.php';
if (!is_file($configPath)) {
    respond(503, ['ok' => false, 'error' => 'Gateway config.php bulunamadı.']);
}
$config = require $configPath;

if (($config['require_https'] ?? true) && !isHttps()) {
    respond(426, ['ok' => false, 'error' => 'HTTPS bağlantısı gereklidir.']);
}

$maxPayload = (int)($config['max_payload_bytes'] ?? 10485760);
if ((int)($_SERVER['CONTENT_LENGTH'] ?? 0) > $maxPayload) {
    respond(413, ['ok' => false, 'error' => 'İstek boyutu sınırı aşıldı.']);
}

$databasePath = (string)($config['database_path'] ?? '');
if ($databasePath === '') {
    respond(503, ['ok' => false, 'error' => 'Veritabanı yolu yapılandırılmadı.']);
}
$databaseDirectory = dirname($databasePath);
if (!is_dir($databaseDirectory) && !mkdir($databaseDirectory, 0750, true)) {
    respond(503, ['ok' => false, 'error' => 'Veritabanı klasörü oluşturulamadı.']);
}

try {
    $db = new PDO('sqlite:' . $databasePath, null, null, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    ]);
    $db->exec('PRAGMA journal_mode=WAL');
    $db->exec('PRAGMA busy_timeout=5000');
    initializeDatabase($db);
} catch (Throwable $error) {
    respond(503, ['ok' => false, 'error' => 'Gateway veritabanı açılamadı.']);
}

$method = strtoupper($_SERVER['REQUEST_METHOD'] ?? 'GET');
$path = routePath();

try {
    if ($method === 'GET' && $path === '/health') {
        respond(200, [
            'ok' => true,
            'protocol' => 'biomed-servis-remote-v1',
            'version' => '1.0.0',
            'time' => gmdate(DATE_ATOM),
        ]);
    }

    if ($method === 'POST' && $path === '/v1/pair/request') {
        $body = jsonBody();
        requireSiteCode($body, $config);
        $deviceId = requiredString($body, 'deviceId');
        $technicianId = requiredString($body, 'technicianId');
        $requestId = bin2hex(random_bytes(16));
        $now = gmdate(DATE_ATOM);

        $db->beginTransaction();
        $cancel = $db->prepare(
            "UPDATE pairing_requests
             SET status = 'superseded', updated_at = :updated
             WHERE device_id = :device AND status = 'pending'"
        );
        $cancel->execute([':updated' => $now, ':device' => $deviceId]);
        $insert = $db->prepare(
            'INSERT INTO pairing_requests
             (id, device_id, technician_id, payload_json, status, requested_at, updated_at)
             VALUES (:id, :device, :technician, :payload, :status, :requested, :updated)'
        );
        $insert->execute([
            ':id' => $requestId,
            ':device' => $deviceId,
            ':technician' => $technicianId,
            ':payload' => json_encode($body, JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR),
            ':status' => 'pending',
            ':requested' => $now,
            ':updated' => $now,
        ]);
        $db->commit();
        respond(202, ['ok' => true, 'requestId' => $requestId, 'status' => 'pending']);
    }

    if ($method === 'GET' && $path === '/v1/pair/status') {
        requireQuerySiteCode($config);
        $requestId = trim((string)($_GET['requestId'] ?? ''));
        $deviceId = trim((string)($_GET['deviceId'] ?? ''));
        $query = $db->prepare(
            'SELECT status, device_token FROM pairing_requests
             WHERE id = :id AND device_id = :device LIMIT 1'
        );
        $query->execute([':id' => $requestId, ':device' => $deviceId]);
        $row = $query->fetch();
        if (!$row) {
            respond(404, ['ok' => false, 'error' => 'Eşleşme isteği bulunamadı.']);
        }
        respond(200, [
            'ok' => true,
            'status' => $row['status'],
            'deviceToken' => $row['status'] === 'approved' ? $row['device_token'] : null,
        ]);
    }

    if ($method === 'GET' && $path === '/v1/center/pairings') {
        requireCenter($config);
        $rows = $db->query(
            "SELECT id, device_id, technician_id, payload_json, requested_at
             FROM pairing_requests WHERE status = 'pending'
             ORDER BY requested_at ASC LIMIT 100"
        )->fetchAll();
        $items = array_map(static fn(array $row): array => [
            'id' => $row['id'],
            'deviceId' => $row['device_id'],
            'technicianId' => $row['technician_id'],
            'payload' => json_decode($row['payload_json'], true, 512, JSON_THROW_ON_ERROR),
            'requestedAt' => $row['requested_at'],
        ], $rows);
        respond(200, ['ok' => true, 'items' => $items]);
    }

    if ($method === 'POST' &&
        preg_match('#^/v1/center/pairings/([a-f0-9]+)/(?P<action>approve|reject)$#', $path, $matches)) {
        requireCenter($config);
        $requestId = $matches[1];
        $action = $matches['action'];
        $status = $action === 'approve' ? 'approved' : 'rejected';
        $deviceToken = $action === 'approve' ? bin2hex(random_bytes(32)) : null;
        $update = $db->prepare(
            'UPDATE pairing_requests
             SET status = :status, device_token = :token, updated_at = :updated
             WHERE id = :id AND status = :pending'
        );
        $update->execute([
            ':status' => $status,
            ':token' => $deviceToken,
            ':updated' => gmdate(DATE_ATOM),
            ':id' => $requestId,
            ':pending' => 'pending',
        ]);
        if ($update->rowCount() !== 1) {
            respond(404, ['ok' => false, 'error' => 'Bekleyen eşleşme bulunamadı.']);
        }
        respond(200, ['ok' => true, 'status' => $status]);
    }

    if ($method === 'POST' && $path === '/v1/mobile/sync') {
        $pairing = requireDevice($db);
        $body = jsonBody();
        $bundle = $body['bundle'] ?? null;
        if (!is_array($bundle)) {
            respond(422, ['ok' => false, 'error' => 'Senkron paketi eksik.']);
        }
        $now = gmdate(DATE_ATOM);
        $insert = $db->prepare(
            "INSERT INTO relay_messages
             (device_id, technician_id, direction, payload_json, created_at)
             VALUES (:device, :technician, 'to_center', :payload, :created)"
        );
        $insert->execute([
            ':device' => $pairing['device_id'],
            ':technician' => $pairing['technician_id'],
            ':payload' => json_encode($bundle, JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR),
            ':created' => $now,
        ]);

        $outbox = $db->prepare(
            "SELECT id, payload_json FROM relay_messages
             WHERE device_id = :device AND direction = 'to_mobile' AND consumed_at IS NULL
             ORDER BY id ASC LIMIT 1"
        );
        $outbox->execute([':device' => $pairing['device_id']]);
        $outbound = $outbox->fetch();
        respond(200, [
            'ok' => true,
            'outboundMessageId' => $outbound ? (int)$outbound['id'] : null,
            'outboundBundle' => $outbound
                ? json_decode($outbound['payload_json'], true, 512, JSON_THROW_ON_ERROR)
                : null,
        ]);
    }

    if ($method === 'POST' &&
        preg_match('#^/v1/mobile/outbox/(\d+)/ack$#', $path, $matches)) {
        $pairing = requireDevice($db);
        $update = $db->prepare(
            "UPDATE relay_messages SET consumed_at = :consumed
             WHERE id = :id AND device_id = :device
               AND direction = 'to_mobile' AND consumed_at IS NULL"
        );
        $update->execute([
            ':consumed' => gmdate(DATE_ATOM),
            ':id' => (int)$matches[1],
            ':device' => $pairing['device_id'],
        ]);
        respond(200, ['ok' => true]);
    }

    if ($method === 'GET' && $path === '/v1/center/inbox') {
        requireCenter($config);
        $rows = $db->query(
            "SELECT id, device_id, technician_id, payload_json
             FROM relay_messages
             WHERE direction = 'to_center' AND consumed_at IS NULL
             ORDER BY id ASC LIMIT 50"
        )->fetchAll();
        $items = array_map(static fn(array $row): array => [
            'id' => (int)$row['id'],
            'deviceId' => $row['device_id'],
            'technicianId' => $row['technician_id'],
            'bundle' => json_decode($row['payload_json'], true, 512, JSON_THROW_ON_ERROR),
        ], $rows);
        respond(200, ['ok' => true, 'items' => $items]);
    }

    if ($method === 'POST' &&
        preg_match('#^/v1/center/inbox/(\d+)/ack$#', $path, $matches)) {
        requireCenter($config);
        $update = $db->prepare(
            'UPDATE relay_messages SET consumed_at = :consumed
             WHERE id = :id AND direction = :direction'
        );
        $update->execute([
            ':consumed' => gmdate(DATE_ATOM),
            ':id' => (int)$matches[1],
            ':direction' => 'to_center',
        ]);
        respond(200, ['ok' => true]);
    }

    if ($method === 'POST' && $path === '/v1/center/outbox') {
        requireCenter($config);
        $body = jsonBody();
        $deviceId = requiredString($body, 'deviceId');
        $bundle = $body['bundle'] ?? null;
        if (!is_array($bundle)) {
            respond(422, ['ok' => false, 'error' => 'Görev paketi eksik.']);
        }
        $technician = $db->prepare(
            "SELECT technician_id FROM pairing_requests
             WHERE device_id = :device AND status = 'approved'
             ORDER BY updated_at DESC LIMIT 1"
        );
        $technician->execute([':device' => $deviceId]);
        $pairing = $technician->fetch();
        if (!$pairing) {
            respond(404, ['ok' => false, 'error' => 'Onaylı mobil cihaz bulunamadı.']);
        }
        $insert = $db->prepare(
            "INSERT INTO relay_messages
             (device_id, technician_id, direction, payload_json, created_at)
             VALUES (:device, :technician, 'to_mobile', :payload, :created)"
        );
        $insert->execute([
            ':device' => $deviceId,
            ':technician' => $pairing['technician_id'],
            ':payload' => json_encode($bundle, JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR),
            ':created' => gmdate(DATE_ATOM),
        ]);
        respond(202, ['ok' => true]);
    }

    respond(404, ['ok' => false, 'error' => 'Endpoint bulunamadı.']);
} catch (JsonException $error) {
    respond(400, ['ok' => false, 'error' => 'Geçersiz JSON.']);
} catch (Throwable $error) {
    error_log('Biomed Gateway: ' . $error->getMessage());
    respond(500, ['ok' => false, 'error' => 'Gateway işlemi tamamlanamadı.']);
}

function initializeDatabase(PDO $db): void
{
    $db->exec(
        'CREATE TABLE IF NOT EXISTS pairing_requests (
            id TEXT PRIMARY KEY,
            device_id TEXT NOT NULL,
            technician_id TEXT NOT NULL,
            payload_json TEXT NOT NULL,
            status TEXT NOT NULL,
            device_token TEXT,
            requested_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
        )'
    );
    $db->exec(
        'CREATE INDEX IF NOT EXISTS idx_pairing_status
         ON pairing_requests(status, requested_at)'
    );
    $db->exec(
        'CREATE TABLE IF NOT EXISTS relay_messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            device_id TEXT NOT NULL,
            technician_id TEXT NOT NULL,
            direction TEXT NOT NULL,
            payload_json TEXT NOT NULL,
            created_at TEXT NOT NULL,
            consumed_at TEXT
        )'
    );
    $db->exec(
        'CREATE INDEX IF NOT EXISTS idx_relay_queue
         ON relay_messages(direction, consumed_at, id)'
    );
}

function routePath(): string
{
    $uriPath = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?: '/';
    $scriptName = str_replace('\\', '/', $_SERVER['SCRIPT_NAME'] ?? '');
    $base = rtrim(str_replace('/index.php', '', $scriptName), '/');
    if ($base !== '' && str_starts_with($uriPath, $base)) {
        $uriPath = substr($uriPath, strlen($base)) ?: '/';
    }
    return '/' . ltrim($uriPath, '/');
}

function jsonBody(): array
{
    $raw = file_get_contents('php://input');
    $decoded = json_decode($raw ?: '{}', true, 512, JSON_THROW_ON_ERROR);
    if (!is_array($decoded)) {
        respond(400, ['ok' => false, 'error' => 'JSON nesnesi bekleniyor.']);
    }
    return $decoded;
}

function requiredString(array $body, string $key): string
{
    $value = trim((string)($body[$key] ?? ''));
    if ($value === '') {
        respond(422, ['ok' => false, 'error' => $key . ' zorunludur.']);
    }
    return $value;
}

function requireSiteCode(array $body, array $config): void
{
    $provided = trim((string)($body['siteCode'] ?? ''));
    $expected = trim((string)($config['site_code'] ?? ''));
    if ($expected === '' || !hash_equals($expected, $provided)) {
        respond(403, ['ok' => false, 'error' => 'Site kodu geçersiz.']);
    }
}

function requireQuerySiteCode(array $config): void
{
    $provided = trim((string)($_GET['siteCode'] ?? ''));
    $expected = trim((string)($config['site_code'] ?? ''));
    if ($expected === '' || !hash_equals($expected, $provided)) {
        respond(403, ['ok' => false, 'error' => 'Site kodu geçersiz.']);
    }
}

function requireCenter(array $config): void
{
    $provided = bearerToken();
    $expected = trim((string)($config['center_token'] ?? ''));
    if ($expected === '' || !hash_equals($expected, $provided)) {
        respond(401, ['ok' => false, 'error' => 'Desktop merkez anahtarı geçersiz.']);
    }
}

function requireDevice(PDO $db): array
{
    $token = bearerToken();
    if ($token === '') {
        respond(401, ['ok' => false, 'error' => 'Mobil cihaz anahtarı eksik.']);
    }
    $query = $db->prepare(
        "SELECT device_id, technician_id FROM pairing_requests
         WHERE device_token = :token AND status = 'approved' LIMIT 1"
    );
    $query->execute([':token' => $token]);
    $row = $query->fetch();
    if (!$row) {
        respond(401, ['ok' => false, 'error' => 'Mobil cihaz eşleşmesi geçersiz.']);
    }
    return $row;
}

function bearerToken(): string
{
    $header = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
    if (!preg_match('/^Bearer\s+(.+)$/i', $header, $matches)) {
        return '';
    }
    return trim($matches[1]);
}

function isHttps(): bool
{
    if (strtolower((string)($_SERVER['HTTPS'] ?? '')) === 'on') {
        return true;
    }
    return strtolower((string)($_SERVER['HTTP_X_FORWARDED_PROTO'] ?? '')) === 'https';
}

function respond(int $status, array $body): never
{
    http_response_code($status);
    echo json_encode($body, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}
