import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../data/datasources/camera_datasource.dart';
import '../../data/datasources/mjpeg_server.dart';
import '../../data/repositories/camera_repository_impl.dart';
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
        repository: CameraRepositoryImpl(
          cameraDatasource: CameraDatasource(),
          mjpegServer: MjpegServer(),
        ),
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
      appBar: AppBar(title: const Text('Baby Monitor - Servidor')),
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
    final controller = cubit.cameraController;

    return Column(
      children: [
        Expanded(
          child: CameraPreviewWidget(
            controller: controller,
            isStreaming: isStreaming,
          ),
        ),
        if (state.streamUrl != null)
          ConnectionInfoWidget(
            streamUrl: state.streamUrl,
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
