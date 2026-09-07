/// This file is a part of media_kit (https://github.com/media-kit/media-kit).
///
/// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
/// All rights reserved.
/// Use of this source code is governed by MIT license that can be found in the LICENSE file.
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:media_kit/generated/libmpv/bindings.dart' as generated;
import 'package:path/path.dart' as path;

import 'package:media_kit/ffi/src/allocation.dart';

/// Callback invoked to notify about the released references.
typedef NativeReferenceHolderCallback =
    void Function(List<Pointer<generated.mpv_handle>>);

/// {@template native_reference_holder}
///
/// NativeReferenceHolder
/// ---------------------
/// Holds references to [Pointer<generated.mpv_handle>]s created during the application runtime, while running in debug mode.
/// These references can be used to dispose the [Pointer<generated.mpv_handle>]s when they are no longer needed i.e. upon hot-restart.
///
/// {@endtemplate}
abstract final class NativeReferenceHolder {
  /// Maximum number of references that can be held.
  static const int kReferenceBufferSize = 512;

  /// Whether the [instance] is initialized.
  static bool initialized = false;

  /// Initializes the instance.
  static void ensureInitialized(NativeReferenceHolderCallback callback) {
    if (initialized) return;
    initialized = true;
    _ensureInitialized(callback);
  }

  static void _ensureInitialized(NativeReferenceHolderCallback callback) {
    if (!_file.existsSync()) {
      // Allocate reference buffer.
      _referenceBuffer = calloc(kReferenceBufferSize);
      final address = _referenceBuffer.address;
      final raf = _file.openSync(mode: FileMode.writeOnly);
      raf.writeFromSync(
        (ByteData(8)..setInt64(0, address)).buffer.asUint8List(),
      );
      raf.close();
      print('$kTag Allocated $address');
    } else {
      // Locate reference buffer.
      final raf = _file.openSync();
      final address = raf.readSync(8).buffer.asByteData().getInt64(0);
      _referenceBuffer = Pointer.fromAddress(address);
      print('$kTag Located $address');
    }

    final references = <Pointer<generated.mpv_handle>>[];

    for (int i = 0; i < kReferenceBufferSize; i++) {
      final referencePtr = _referenceBuffer + i;
      final referenceAddress = referencePtr.value;
      referencePtr.value = 0;
      if (referenceAddress != 0) {
        references.add(Pointer.fromAddress(referenceAddress));
      }
    }

    callback(references);
  }

  /// Saves the reference.
  static void add(Pointer reference) {
    if (!initialized) return;
    if (reference == nullptr) return;
    for (int i = 0; i < kReferenceBufferSize; i++) {
      final referenceValue = _referenceBuffer + i;
      final referencePtr = Pointer.fromAddress(referenceValue.value);
      // NOTE: Do not compare .value with .address. Bad things may happen on 32-bit systems.
      if (referencePtr.address == 0) {
        referenceValue.value = reference.address;
        break;
      }
    }
  }

  /// Removes the reference.
  static void remove(Pointer reference) {
    if (!initialized) return;
    if (reference == nullptr) return;
    for (int i = 0; i < kReferenceBufferSize; i++) {
      final referenceValue = _referenceBuffer + i;
      final referencePtr = Pointer.fromAddress(referenceValue.value);
      // NOTE: Do not compare .value with .address. Bad things may happen on 32-bit systems.
      if (referencePtr.address == reference.address) {
        referenceValue.value = 0;
        break;
      }
    }
  }

  /// [File] used to store [int] address to the reference buffer.
  /// This is necessary to have a persistent to the reference buffer across hot-restarts.
  static final File _file = File(
    path.join(
      Directory.systemTemp.path,
      'com.alexmercerind.media_kit.NativeReferenceHolder.$pid',
    ),
  );

  /// [Pointer] to the reference buffer.
  static late final Pointer<Size> _referenceBuffer;

  static const String kTag = 'media_kit: NativeReferenceHolder:';
}
