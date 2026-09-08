/// This file is a part of media_kit (https://github.com/media-kit/media-kit).
///
/// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
/// All rights reserved.
/// Use of this source code is governed by MIT license that can be found in the LICENSE file.
import 'dart:async';
import 'dart:collection';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:media_kit/generated/libmpv/bindings.dart' as generated;
import 'package:media_kit/src/player/native/core/initializer_native_callable.dart';
import 'package:media_kit/src/player/native/player/real.dart';

/// {@template initializer_native_event_loop}
///
/// InitializerNativeEventLoop
/// -------------------------
/// Initializes [Pointer<mpv_handle>] & notifies about events through the supplied callback.
///
/// {@endtemplate}
abstract final class InitializerNativeEventLoop {
  /// Initializes the |InitializerNativeEventLoop| class for usage.
  @pragma('vm:prefer-inline')
  static Pointer<NativeFunction<WakeUpCallback>> _initHandle() {
    final dylib = DynamicLibrary.open(
      Platform.isMacOS || Platform.isIOS
          ? 'media_kit_native_event_loop.framework/media_kit_native_event_loop'
          : Platform.isAndroid || Platform.isLinux
          ? 'libmedia_kit_native_event_loop.so'
          : Platform.isWindows
          ? 'media_kit_native_event_loop.dll'
          : throw UnimplementedError(),
    );

    dylib.lookupFunction<_HandlerInitializeCXX, _HandlerInitializeDart>(
      'MediaKitEventLoopHandlerInitialize',
      isLeaf: true,
    )(NativeApi.postCObject, _receiver.sendPort.nativePort);

    final handle = dylib.lookup<NativeFunction<WakeUpCallback>>(
      'MediaKitEventLoopHandlerCallback',
    );
    _handleWakeup();
    return handle;
  }

  /// Creates [Pointer<mpv_handle>].
  static Pointer<generated.mpv_handle> create(
    FutureOr<void> Function(Pointer<generated.mpv_event>) callback, {
    Map<String, String> options = const {},
  }) {
    final handle = _handle;
    final ctx = NativePlayer.mpv.mpv_create();
    for (final entry in options.entries) {
      NativePlayer.mpv.setOption(ctx, entry.key, entry.value);
    }
    NativePlayer.mpv.mpv_initialize(ctx);
    _eventCallbacks[ctx.address] = callback;
    NativePlayer.mpv.mpv_set_wakeup_callback(ctx, handle.cast(), ctx.cast());
    return ctx;
  }

  /// Disposes [Pointer<mpv_handle>].
  static void dispose(Pointer<generated.mpv_handle> ctx) {
    _eventCallbacks.remove(ctx.address);

    // Clear the wakeup callback in libmpv before closing NativeCallable
    // to prevent libmpv from invoking a deleted callback
    NativePlayer.mpv.mpv_set_wakeup_callback(ctx, nullptr, nullptr);
  }

  static Future<void> _handleWakeup() async {
    await for (final int handle in _receiver) {
      final callback = _eventCallbacks[handle];
      if (callback == null) continue;

      final ctx = Pointer<generated.mpv_handle>.fromAddress(handle);
      while (true) {
        final event = NativePlayer.mpv.mpv_wait_event(ctx, 0);
        if (event == nullptr ||
            event.ref.event_id == generated.mpv_event_id.MPV_EVENT_NONE) {
          break;
        }
        try {
          await callback(event);
        } catch (error, stackTrace) {
          Zone.current.handleUncaughtError(error, stackTrace);
        }
      }
    }
  }

  static final _receiver = ReceivePort();

  static final _eventCallbacks = HashMap<int, EventCallback>();
  static final _handle = _initHandle();
  static bool get inited => _eventCallbacks.isNotEmpty;
}

typedef _HandlerCallback =
    Pointer<NativeFunction<Int8 Function(Int64, Pointer<Dart_CObject>)>>;

typedef _HandlerInitializeCXX = Void Function(_HandlerCallback, Int64);
typedef _HandlerInitializeDart = void Function(_HandlerCallback, int);
