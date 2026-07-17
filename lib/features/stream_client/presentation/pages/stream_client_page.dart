import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../domain/repositories/stream_client_repository.dart';
import '../cubit/stream_client_cubit.dart';
import '../cubit/stream_client_state.dart';
import '../widgets/mjpeg_viewer.dart';

class StreamClientPage extends StatefulWidget {
  const StreamClientPage({super.key});

  @override
  State<StreamClientPage> createState() => _StreamClientPageState();
}

class _StreamClientPageState extends State<StreamClientPage> {
  final _urlController = TextEditingController();
  late final StreamClientCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = StreamClientCubit(repository: sl<StreamClientRepository>());
  }

  @override
  void dispose() {
    _urlController.dispose();
    _cubit.close();
    super.dispose();
  }

  void _connect() {
    final url = _urlController.text.trim();
    if (url.isNotEmpty) {
      _cubit.connect(url);
    }
  }

  void _showFullscreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              MjpegViewerWidget(frameStream: _cubit.frameStream),
              Positioned(
                top: 40,
                left: 16,
                child: SafeArea(
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Baby Monitor - Cliente'),
          actions: [
            if (_cubit.state.status == StreamClientStatus.connected)
              IconButton(
                icon: const Icon(Icons.fullscreen),
                onPressed: () => _showFullscreen(context),
                tooltip: 'Pantalla completa',
              ),
          ],
        ),
        body: BlocBuilder<StreamClientCubit, StreamClientState>(
          bloc: _cubit,
          builder: (context, state) {
            return _buildBody(context, state);
          },
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, StreamClientState state) {
    return Column(
      children: [
        if (state.status != StreamClientStatus.connected)
          _buildConnectionBar(context, state),
        Expanded(
          child: state.status == StreamClientStatus.connected
              ? MjpegViewerWidget(frameStream: _cubit.frameStream)
              : _buildPlaceholder(context, state),
        ),
      ],
    );
  }

  Widget _buildConnectionBar(BuildContext context, StreamClientState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              hintText: 'http://192.168.1.100:8080/stream',
              labelText: 'URL del stream',
              prefixIcon: Icon(Icons.link),
            ),
            keyboardType: TextInputType.url,
            onSubmitted: (_) => _connect(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed:
                  state.status == StreamClientStatus.connecting ? null : _connect,
              icon: state.status == StreamClientStatus.connecting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow),
              label: Text(
                state.status == StreamClientStatus.connecting
                    ? 'Conectando...'
                    : 'Conectar',
              ),
            ),
          ),
          if (state.errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              state.errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context, StreamClientState state) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.videocam_off,
            size: 64,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 16),
          Text(
            'Ingresa la URL del servidor\ny presiona Conectar',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}
