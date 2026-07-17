import 'package:equatable/equatable.dart';

enum StreamClientStatus { initial, connecting, connected, error, disconnected }

class StreamClientState extends Equatable {
  final StreamClientStatus status;
  final String? errorMessage;

  const StreamClientState({
    this.status = StreamClientStatus.initial,
    this.errorMessage,
  });

  StreamClientState copyWith({
    StreamClientStatus? status,
    String? errorMessage,
    bool clearError = false,
  }) {
    return StreamClientState(
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, errorMessage];
}
