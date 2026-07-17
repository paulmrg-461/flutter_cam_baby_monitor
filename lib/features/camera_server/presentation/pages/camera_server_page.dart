import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/security/token_storage.dart';
import '../../domain/repositories/camera_repository.dart';
import '../cubit/camera_server_cubit.dart';
import '../cubit/camera_server_state.dart';
import '../widgets/camera_preview.dart';
import '../widgets/connection_info.dart';

class CameraServerPage extends StatelessWidget {
  const CameraServerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CameraServerCubit(
        repository: sl<CameraRepository>(),
        tokenStorage: sl<TokenStorage>(),
      ),
      child: const _CameraServerView(),
    );
  }
}

class _CameraServerView extends StatefulWidget {
  const _CameraServerView();

  @override
  State<_CameraServerView> createState() => _CameraServerViewState();
}

class _CameraServerViewState extends State<_CameraServerView> {
  @override
  void initState() {
    super.initState();
    _requestPermissionAndInit();
  }

  Future<void> _requestPermissionAndInit() async {
    final status = await Permission.camera.request();
    if (status.isGranted && mounted) {
      context.read<CameraServerCubit>().initialize();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Baby Monitor - Servidor'),
        actions: [
          BlocBuilder<CameraServerCubit, CameraServerState>(
            builder: (context, state) {
              if (state.streamUrl == null) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.vpn_key),
                tooltip: 'Regenerar token de acceso',
                onPressed: () => _confirmRegenerateToken(context),
              );
            },
          ),
        ],
      ),
      body: BlocConsumer<CameraServerCubit, CameraServerState>(
        listener: (context, state) {
          if (state.status == CameraServerStatus.error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage ?? 'Error desconocido'),
                backgroundColor: Colors.red,
                action: SnackBarAction(
                  label: 'Reintentar',
                  textColor: Colors.white,
                  onPressed: _requestPermissionAndInit,
                ),
              ),
            );
          }
        },
        builder: (context, state) {
          return _buildBody(context, state);
        },
      ),
    );
  }

  Future<void> _confirmRegenerateToken(BuildContext context) async {
    final cubit = context.read<CameraServerCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Regenerar token'),
        content: const Text(
          'Esto invalida el URL actual. Cualquier dispositivo con el link '
          'viejo va a dejar de poder ver la camara.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Regenerar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await cubit.regenerateToken();
    }
  }

  Widget _buildBody(BuildContext context, CameraServerState state) {
    switch (state.status) {
      case CameraServerStatus.initial:
      case CameraServerStatus.initializing:
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Inicializando camara...'),
            ],
          ),
        );
      case CameraServerStatus.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  state.errorMessage ?? 'Error desconocido',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _requestPermissionAndInit,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        );
      case CameraServerStatus.initialized:
      case CameraServerStatus.streaming:
      case CameraServerStatus.stopped:
        return _buildStreamingView(context, state);
    }
  }

  Widget _buildStreamingView(BuildContext context, CameraServerState state) {
    final cubit = context.read<CameraServerCubit>();
    final isStreaming = state.status == CameraServerStatus.streaming;

    return Column(
      children: [
        Expanded(
          child: state.isBackgroundCapture
              ? const _BackgroundCaptureNotice()
              : CameraPreviewWidget(
                  controller: cubit.cameraController,
                  isStreaming: isStreaming,
                ),
        ),
        if (state.streamUrl != null)
          ConnectionInfoWidget(
            streamUrl: state.streamUrl,
            browserUrl: state.browserUrl,
            localIp: state.localIp,
            port: state.port,
          ),
        _buildControls(context, isStreaming, cubit),
      ],
    );
  }

  Widget _buildControls(
    BuildContext context,
    bool isStreaming,
    CameraServerCubit cubit,
  ) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              icon: const Icon(Icons.switch_camera),
              onPressed: cubit.toggleCamera,
              tooltip: 'Cambiar camara',
              iconSize: 28,
            ),
            FloatingActionButton.extended(
              heroTag: 'stream_toggle',
              onPressed: cubit.toggleStreaming,
              backgroundColor: isStreaming
                  ? Colors.red
                  : Theme.of(context).colorScheme.primary,
              icon: Icon(isStreaming ? Icons.stop : Icons.play_arrow),
              label: Text(isStreaming ? 'Detener' : 'Iniciar Stream'),
            ),
            const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }
}

class _BackgroundCaptureNotice extends StatelessWidget {
  const _BackgroundCaptureNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.visibility_off_outlined, size: 48, color: Colors.white54),
            SizedBox(height: 16),
            Text(
              'Transmitiendo en segundo plano',
              style: TextStyle(color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }
}
