import 'dart:io';
import 'dart:convert';

import 'package:biomed_serv/services/lan_sync_service.dart';

class WindowsFirewallStatus {
  final bool tcpRuleEnabled;
  final bool udpRuleEnabled;
  final bool localApiResponding;

  const WindowsFirewallStatus({
    required this.tcpRuleEnabled,
    required this.udpRuleEnabled,
    required this.localApiResponding,
  });

  bool get isReady => tcpRuleEnabled && udpRuleEnabled && localApiResponding;
}

class WindowsFirewallService {
  static const tcpRuleName = 'Biomed Servis Yerel API TCP';
  static const udpRuleName = 'Biomed Servis Otomatik Kesif UDP';
  static const legacyRuleName = 'Biomed Servis Yerel API';

  Future<WindowsFirewallStatus> inspect() async {
    if (!Platform.isWindows) {
      return const WindowsFirewallStatus(
        tcpRuleEnabled: false,
        udpRuleEnabled: false,
        localApiResponding: false,
      );
    }

    final results = await Future.wait([
      _isRuleEnabled(tcpRuleName),
      _isRuleEnabled(udpRuleName),
      _testLocalApi(),
    ]);
    return WindowsFirewallStatus(
      tcpRuleEnabled: results[0],
      udpRuleEnabled: results[1],
      localApiResponding: results[2],
    );
  }

  Future<bool> configureWithElevation() async {
    if (!Platform.isWindows) return false;

    final executable = Platform.resolvedExecutable.replaceAll("'", "''");
    final script = '''
\$ErrorActionPreference = 'Stop'
\$programPath = '$executable'
\$ruleNames = @(
  '$legacyRuleName',
  '$tcpRuleName',
  '$udpRuleName'
)
foreach (\$ruleName in \$ruleNames) {
  Get-NetFirewallRule -DisplayName \$ruleName -ErrorAction SilentlyContinue |
    Remove-NetFirewallRule -ErrorAction SilentlyContinue
}
New-NetFirewallRule -DisplayName '$tcpRuleName' -Direction Inbound -Action Allow -Protocol TCP -LocalPort ${LanSyncService.defaultPort} -RemoteAddress LocalSubnet -Profile Any -Program \$programPath -Enabled True | Out-Null
New-NetFirewallRule -DisplayName '$udpRuleName' -Direction Inbound -Action Allow -Protocol UDP -LocalPort ${LanSyncService.discoveryPort} -RemoteAddress LocalSubnet -Profile Any -Program \$programPath -Enabled True | Out-Null
''';

    final scriptFile = File(
      '${Directory.systemTemp.path}\\biomed_firewall_${DateTime.now().microsecondsSinceEpoch}.ps1',
    );
    await scriptFile.writeAsString(script, flush: true);
    final scriptPath = scriptFile.path.replaceAll("'", "''");

    try {
      final command = '''
\$process = Start-Process -FilePath 'powershell.exe' -Verb RunAs -Wait -PassThru -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File','$scriptPath')
exit \$process.ExitCode
''';
      final result = await Process.run(
        'powershell.exe',
        ['-NoProfile', '-NonInteractive', '-Command', command],
        runInShell: false,
      );
      return result.exitCode == 0;
    } catch (_) {
      return false;
    } finally {
      if (await scriptFile.exists()) {
        await scriptFile.delete();
      }
    }
  }

  Future<bool> _isRuleEnabled(String displayName) async {
    final escapedName = displayName.replaceAll("'", "''");
    final command = '''
\$rule = Get-NetFirewallRule -DisplayName '$escapedName' -ErrorAction SilentlyContinue |
  Where-Object { \$_.Enabled -eq 'True' } |
  Select-Object -First 1
if (\$null -eq \$rule) { exit 1 } else { exit 0 }
''';
    try {
      final result = await Process.run(
        'powershell.exe',
        ['-NoProfile', '-NonInteractive', '-Command', command],
        runInShell: false,
      );
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _testLocalApi() async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 2)
      ..idleTimeout = const Duration(seconds: 2);
    try {
      final request = await client.getUrl(
        Uri.parse(
          'http://127.0.0.1:${LanSyncService.defaultPort}/health',
        ),
      );
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        return false;
      }
      final content = await utf8.decoder.bind(response).join();
      final payload = jsonDecode(content);
      if (payload is! Map) return false;
      return payload['ok'] == true &&
          payload['protocol']?.toString() == LanSyncService.healthProtocol;
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }
}
