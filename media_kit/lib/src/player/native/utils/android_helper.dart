/// This file is a part of media_kit (https://github.com/media-kit/media-kit).
///
/// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
/// All rights reserved.
/// Use of this source code is governed by MIT license that can be found in the LICENSE file.
// ignore_for_file: non_constant_identifier_names, camel_case_types
import 'dart:ffi';
import 'package:jni/jni.dart';
import 'package:media_kit/ffi/src/allocation.dart';

/// {@template android_helper}
///
/// AndroidHelper
/// -------------
///
/// Learn more: https://github.com/media-kit/media-kit-android-helper
///
/// {@endtemplate}
abstract final class AndroidHelper {
  static set_java_vmDart _getSetJvm(String lib, String func) =>
      DynamicLibrary.open(
        lib,
      ).lookupFunction<set_java_vmCXX, set_java_vmDart>(func, isLeaf: true);

  /// {@macro android_helper}
  static void ensureInitialized({String? libmpv}) {
    set_java_vmDart? set_java_vm;
    // Look for the required symbols.
    try {
      set_java_vm = _getSetJvm(libmpv ?? 'libmpv.so', 'mpv_lavc_set_java_vm');
    } catch (_) {
      try {
        set_java_vm = _getSetJvm('libavcodec.so', 'av_jni_set_java_vm');
      } catch (_) {
        throw UnsupportedError(
          'Cannot load mpv_lavc_set_java_vm (libmpv.so) and av_jni_set_java_vm (libavcodec.so).',
        );
      }
    }

    final ptr = calloc<Pointer<Void>>();
    // TODO: Jni.GetJavaVM
    // ignore: invalid_use_of_internal_member
    Jni.env.GetJavaVM(ptr.cast());
    final vm = ptr.value;
    if (vm == nullptr) {
      throw StateError('JavaVM Pointer is null.');
    } else {
      set_java_vm(vm);
    }
  }
}

typedef set_java_vmCXX = Int32 Function(Pointer<Void> vm);
typedef set_java_vmDart = int Function(Pointer<Void> vm);
