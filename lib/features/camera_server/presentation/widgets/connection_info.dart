import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ConnectionInfoWidget extends StatelessWidget {
  final String? streamUrl;
  final String? browserUrl;
  final String? localIp;
  final int? port;

  const ConnectionInfoWidget({
    super.key,
    this.streamUrl,
    this.browserUrl,
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
            _buildHeader(),
            const SizedBox(height: 12),
            if (browserUrl != null)
              _UrlRow(
                context: context,
                label: 'Ver en navegador (cualquier dispositivo)',
                url: browserUrl!,
              ),
            if (browserUrl != null) const SizedBox(height: 12),
            _UrlRow(
              context: context,
              label: 'Pegar en la app cliente (pestaña Cliente)',
              url: streamUrl!,
            ),
            const SizedBox(height: 12),
            Text(
              'Ambos dispositivos deben estar en la misma red WiFi.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Icon(Icons.wifi, size: 20, color: Colors.green),
        const SizedBox(width: 8),
        Builder(
          builder: (context) => Text(
            'Servidor activo',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ],
    );
  }
}

class _UrlRow extends StatelessWidget {
  const _UrlRow({
    required this.context,
    required this.label,
    required this.url,
  });

  final BuildContext context;
  final String label;
  final String url;

  @override
  Widget build(BuildContext _) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: SelectableText(
                  url,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 18),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: url));
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
        ),
      ],
    );
  }
}
