import 'package:equatable/equatable.dart';

enum StreamClientStatus { initial, connecting, connected, error, disconnected }

class StreamClientState extends Equatable {
  final StreamClientStatus status;
  final String? errorMessage;

  /// Increments on every motion alert from the server. A monotonic counter
  /// (rather than a bool) so listeners always see a change to react to,
  /// even for back-to-back alerts.
  final int motionTick;

  const StreamClientState({
    this.status = StreamClientStatus.initial,
    this.errorMessage,
    this.motionTick = 0,
  });

  StreamClientState copyWith({
    StreamClientStatus? status,
    String? errorMessage,
    bool clearError = false,
    int? motionTick,
  }) {
    return StreamClientState(
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      motionTick: motionTick ?? this.motionTick,
    );
  }

  @override
  List<Object?> get props => [status, errorMessage, motionTick];
}
