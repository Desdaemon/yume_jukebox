import 'dart:async';
import 'dart:io';
import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

import 'yume_audio_bindings_generated.dart' as ffi;

class AudioStream {
  final Pointer<ffi.AudioStream> _stream;

  const AudioStream._(this._stream);
  static Future<AudioStream?> init(String path, {double pitch = 1.0}) async {
    final SendPort helperIsolateSendPort = await _helperIsolateSendPort;
    final int requestId = _nextPlayRequestId++;
    final request = PlayRequest(path, pitch: pitch, id: requestId);
    final completer = Completer<AudioStream?>();
    _playRequests[requestId] = completer;
    helperIsolateSendPort.send(request);
    return completer.future;
  }

  void dispose() => _bindings.dispose_stream(_stream);
  set pitch(double pitch) => _bindings.set_pitch(_stream, pitch);

  set _status(int status) => _bindings.request_state_change(_stream, status);

  void pause() => _status = ffi.StreamStatus.pause_stream;
  void start() => _status = ffi.StreamStatus.start_stream;
  void stop() => _status = ffi.StreamStatus.stop_stream;
}

const String _libName = 'yume_audio';

/// The dynamic library in which the symbols for [ffi.YumeAudioBindings] can be found.
final DynamicLibrary _dylib = () {
  if (Platform.isMacOS || Platform.isIOS) {
    return DynamicLibrary.open('$_libName.framework/$_libName');
  }
  if (Platform.isAndroid || Platform.isLinux) {
    return DynamicLibrary.open('lib$_libName.so');
  }
  if (Platform.isWindows) {
    return DynamicLibrary.open('$_libName.dll');
  }
  throw UnsupportedError('Unknown platform: ${Platform.operatingSystem}');
}();

/// The bindings to the native functions in [_dylib].
final ffi.YumeAudioBindings _bindings = ffi.YumeAudioBindings(_dylib);

sealed class FfiRequest {
  final int id;
  const FfiRequest({required this.id});
}

final class PlayRequest extends FfiRequest {
  final String path;
  final double pitch;
  const PlayRequest(this.path, {this.pitch = 1.0, required super.id});
}

sealed class FfiResponse {
  final int id;
  const FfiResponse({required this.id});
}

final class PlayResponse extends FfiResponse {
  final Pointer<ffi.AudioStream> stream;
  const PlayResponse({required this.stream, required super.id});
}

/// Counter to identify [FfiRequest]s and [FfiResponse]s.
int _nextPlayRequestId = 0;

/// Mapping from [FfiRequest] `id`s to the completers corresponding to the correct future of the pending request.
final _playRequests = <int, Completer<AudioStream?>>{};

/// The SendPort belonging to the helper isolate.
Future<SendPort> _helperIsolateSendPort = () async {
  // The helper isolate is going to send us back a SendPort, which we want to
  // wait for.
  final Completer<SendPort> completer = Completer<SendPort>();

  // Receive port on the main isolate to receive messages from the helper.
  // We receive two types of messages:
  // 1. A port to send messages on.
  // 2. Responses to requests we sent.
  final ReceivePort receivePort = ReceivePort()
    ..listen((dynamic data) {
      if (data is SendPort) {
        // The helper isolate sent us the port on which we can sent it requests.
        completer.complete(data);
        return;
      }
      if (data is! FfiResponse) {
        throw UnsupportedError('Unsupported message type: ${data.runtimeType}');
      }
      switch (data) {
        case PlayResponse(:var id, :var stream):
          final completer = _playRequests[id]!;
          _playRequests.remove(data.id);
          completer.complete(stream == nullptr ? null : AudioStream._(stream));
      }
    });

  // Start the helper isolate.
  await Isolate.spawn((SendPort sendPort) async {
    final ReceivePort helperReceivePort = ReceivePort()
      ..listen((dynamic data) {
        // On the helper isolate listen to requests and respond to them.
        if (data is! FfiRequest) {
          throw UnsupportedError(
              'Unsupported message type: ${data.runtimeType}');
        }
        switch (data) {
          case PlayRequest(:var path, :var pitch):
            final pathbuf = path.toNativeUtf8();
            final stream = _bindings.play_with_pitch(pathbuf.cast(), pitch);
            final response = PlayResponse(stream: stream, id: data.id);
            sendPort.send(response);
        }
      });

    // Send the port to the main isolate on which we can receive requests.
    sendPort.send(helperReceivePort.sendPort);
  }, receivePort.sendPort);

  // Wait until the helper isolate has sent us back the SendPort on which we
  // can start sending requests.
  return completer.future;
}();
