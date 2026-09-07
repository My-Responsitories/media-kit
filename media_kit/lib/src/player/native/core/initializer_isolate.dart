/// This file is a part of media_kit (https://github.com/media-kit/media-kit).
///
/// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
/// All rights reserved.
/// Use of this source code is governed by MIT license that can be found in the LICENSE file.
import 'dart:ffi';
import 'dart:async';
import 'dart:isolate';
import 'dart:collection';

import 'package:media_kit/generated/libmpv/bindings.dart' as generated;
import 'package:media_kit/src/player/native/core/native_library.dart';
import 'package:media_kit/src/player/native/player/real.dart';
import 'package:media_kit/src/values.dart';

/// {@template initializer_isolate}
///
/// InitializerIsolate
/// ------------------
/// Initializes [Pointer<mpv_handle>] & notifies about events through the supplied callback.
///
/// {@endtemplate}
abstract final class InitializerIsolate {
  /// Creates [Pointer<mpv_handle>].
  static Future<Pointer<generated.mpv_handle>> create(
    FutureOr<void> Function(Pointer<generated.mpv_event>) callback, {
    Map<String, String> options = const {},
  }) async {
    final completer = Completer<int>();
    final receiver = RawReceivePort();
    late final SendPort port;
    final isolate = await Isolate.spawn(_mainloop, receiver.sendPort);
    receiver.handler = (message) async {
      if (!completer.isCompleted && message is SendPort) {
        port = message;
        port.send(options);
        port.send(NativeLibrary.path);
      } else if (!completer.isCompleted && message is int) {
        // Intialiation complete.
        completer.complete(message);
      }
      // Forward events to the supplied callback.
      else if (message != null) {
        Pointer<generated.mpv_event> event = Pointer.fromAddress(message);
        try {
          await callback(event);
        } catch (error, stackTrace) {
          Zone.current.handleUncaughtError(error, stackTrace);
        }
        port.send(true);
      } else {
        receiver.close();
      }
    };
    // Awaiting the retrieval of [Pointer<mpv_handle>].
    final handle = await completer.future;

    // Save the references.
    _ports[handle] = port;
    _isolates[handle] = isolate;

    return Pointer.fromAddress(handle);
  }

  /// Disposes [Pointer<mpv_handle>].
  static void dispose(Pointer<generated.mpv_handle> handle) {
    final port = _ports[handle.address];
    final isolate = _isolates[handle.address];
    if (port != null && isolate != null) {
      port.send(null);

      _ports.remove(handle.address);
      _isolates.remove(handle.address);

      NativePlayer.mpv.mpv_wakeup(handle);

      Future.delayed(const Duration(seconds: 2), () {
        isolate.kill(priority: Isolate.immediate);
      });
    }
  }

  static void _mainloop(SendPort port) async {
    Completer completer = Completer();

    final receiver = RawReceivePort();
    port.send(receiver.sendPort);

    late Map<String, String> options;
    late generated.MPV mpv;

    bool disposed = false;

    Pointer<generated.mpv_handle>? handle;

    receiver.handler = (message) {
      if (message is Map<String, String>) {
        options = message;
      } else if (message is String) {
        mpv = generated.MPV(DynamicLibrary.open(message));
        completer.complete();
      } else if (message is bool) {
        completer.complete();
      } else if (message == null) {
        if (handle != null) {
          disposed = true;
          completer.complete();
        }
      }
    };

    await completer.future;

    handle ??= mpv.mpv_create();

    for (final entry in options.entries) {
      mpv.setOption(handle, entry.key, entry.value);
    }

    mpv.mpv_initialize(handle);
    port.send(handle.address);

    while (!disposed) {
      completer = Completer();
      final event = mpv.mpv_wait_event(handle, kReleaseMode ? -1 : 0.1);
      if (disposed) break;

      if (event.ref.event_id != generated.mpv_event_id.MPV_EVENT_NONE) {
        port.send(event.address);
        await completer.future;
      } else {
        await Future.delayed(Duration.zero);
      }
    }

    port.send(null);
    receiver.close();
  }

  static final _ports = HashMap<int, SendPort>();
  static final _isolates = HashMap<int, Isolate>();
}
