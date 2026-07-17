import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ConnectionInfoWidget extends StatelessWidget {
  final String? streamUrl;
  final String? localIp;
  final int? port;

  const ConnectionInfoWidget({
    super.key,
    this.streamUrl,
    this.localIp,
    this.port,
  });

  @override
  Widget build(BuildContext context) {
    if (streamUrl == null) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.wifi, size: 20, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  'Servidor activo',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.copy, size: 20),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: streamUrl!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('URL copiada al portapapeles'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  tooltip: 'Copiar URL',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                streamUrl!,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Abre esta URL en cualquier dispositivo conectado a la misma red WiFi para ver la camara.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
