/// This file is a part of media_kit (https://github.com/media-kit/media-kit).
///
/// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
/// All rights reserved.
/// Use of this source code is governed by MIT license that can be found in the LICENSE file.
import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';

import 'package:media_kit/generated/libmpv/bindings.dart' as generated;
import 'package:media_kit/src/player/native/core/execmem_restriction.dart';
import 'package:media_kit/src/player/native/core/initializer_isolate.dart';
import 'package:media_kit/src/player/native/core/initializer_native_callable.dart';
import 'package:media_kit/src/values.dart';

/// {@template initializer}
///
/// Initializer
/// -----------
/// Initializes [Pointer<mpv_handle>] & notifies about events through the supplied callback.
///
/// {@endtemplate}
abstract final class Initializer {
  /// Creates [Pointer<mpv_handle>].
  static Future<Pointer<generated.mpv_handle>> create(
    FutureOr<void> Function(Pointer<generated.mpv_event>) callback, {
    Map<String, String> options = const {},
  }) async {
    // Hot-restart tears down the Dart isolate, which invalidates any previously
    // registered `NativeCallable` trampolines. In debug mode, prefer the isolate
    // based implementation to avoid native -> Dart callbacks that can outlive
    // the isolate and crash with "Callback invoked after it has been deleted".
    // See: https://github.com/media-kit/media-kit/issues/1340
    // We still use NativeCallable based implementation in release mode and unit tests for better performance.
    if (kDebugMode && isMainIsolate()) {
      return InitializerIsolate.create(callback, options: options);
    }
    if (!isExecmemRestricted) {
      return InitializerNativeCallable.create(callback, options: options);
    } else {
      return InitializerIsolate.create(callback, options: options);
    }
  }

  /// Disposes [Pointer<mpv_handle>].
  static void dispose(Pointer<generated.mpv_handle> ctx) {
    if (kDebugMode && isMainIsolate()) {
      InitializerIsolate.dispose(ctx);
      return;
    }
    if (!isExecmemRestricted) {
      InitializerNativeCallable.dispose(ctx);
    } else {
      InitializerIsolate.dispose(ctx);
    }
  }

  static bool isMainIsolate() {
    final name = Isolate.current.debugName;
    return name == 'main';
  }
}
