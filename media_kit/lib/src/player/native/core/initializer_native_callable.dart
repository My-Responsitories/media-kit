/// This file is a part of media_kit (https://github.com/media-kit/media-kit).
///
/// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
/// All rights reserved.
/// Use of this source code is governed by MIT license that can be found in the LICENSE file.
import 'dart:async';
import 'dart:collection';
import 'dart:ffi';

import 'package:media_kit/generated/libmpv/bindings.dart' as generated;
import 'package:media_kit/src/player/native/player/real.dart';
import 'package:synchronized/synchronized.dart';

/// {@template initializer_native_callable}
///
/// InitializerNativeCallable
/// -------------------------
/// Initializes [Pointer<mpv_handle>] & notifies about events through the supplied callback.
///
/// {@endtemplate}
abstract final class InitializerNativeCallable {
  /// Creates [Pointer<mpv_handle>].
  static Pointer<generated.mpv_handle> create(
    FutureOr<void> Function(Pointer<generated.mpv_event>) callback, {
    Map<String, String> options = const {},
  }) {
    final ctx = NativePlayer.mpv.mpv_create();
    for (final entry in options.entries) {
      NativePlayer.mpv.setOption(ctx, entry.key, entry.value);
    }
    NativePlayer.mpv.mpv_initialize(ctx);
    final nativeCallable = WakeUpNativeCallable.listener(_callback);
    _locks[ctx.address] = Lock();
    _eventCallbacks[ctx.address] = callback;
    _wakeUpNativeCallables[ctx.address] = nativeCallable;
    NativePlayer.mpv.mpv_set_wakeup_callback(
      ctx,
      nativeCallable.nativeFunction.cast(),
      ctx.cast(),
    );
    return ctx;
  }

  /// Disposes [Pointer<mpv_handle>].
  static void dispose(Pointer<generated.mpv_handle> ctx) {
    _locks.remove(ctx.address);
    _eventCallbacks.remove(ctx.address);

    // Clear the wakeup callback in libmpv before closing NativeCallable
    // to prevent libmpv from invoking a deleted callback
    NativePlayer.mpv.mpv_set_wakeup_callback(ctx, nullptr, nullptr);

    _wakeUpNativeCallables.remove(ctx.address)?.close();
  }

  static void _callback(Pointer<generated.mpv_handle> ctx) {
    _locks[ctx.address]?.synchronized(() async {
      while (true) {
        final event = NativePlayer.mpv.mpv_wait_event(ctx, 0);
        if (event == nullptr ||
            event.ref.event_id == generated.mpv_event_id.MPV_EVENT_NONE) {
          return;
        }
        await _eventCallbacks[ctx.address]?.call(event);
      }
    });
  }

  static final _locks = HashMap<int, Lock>();
  static final _eventCallbacks = HashMap<int, EventCallback>();
  static final _wakeUpNativeCallables = WakeUpNativeCallableMap();
}

typedef WakeUpCallback = Void Function(Pointer<generated.mpv_handle>);
typedef WakeUpNativeCallable = NativeCallable<WakeUpCallback>;
typedef WakeUpNativeCallableMap = HashMap<int, WakeUpNativeCallable>;

typedef EventCallback = FutureOr<void> Function(Pointer<generated.mpv_event>);
