/// This file is a part of media_kit (https://github.com/media-kit/media-kit).
///
/// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
/// All rights reserved.
/// Use of this source code is governed by MIT license that can be found in the LICENSE file.

import 'dart:ffi';

import 'package:test/test.dart';

import 'package:media_kit/ffi/ffi.dart';
import 'package:media_kit/generated/libmpv/bindings.dart';

// `struct mpv_stream_cb_info` is hand-declared in
// `lib/generated/libmpv/bindings.dart` (bound from `stream_cb.h`), so pin its
// ABI here: field count, field order and the signature of every callback slot.

int _readCb(Pointer<Void> cookie, Pointer<Uint8> buf, int nbytes) => 0;
int _seekCb(Pointer<Void> cookie, int offset) => 0;
int _sizeCb(Pointer<Void> cookie) => 0;
void _closeCb(Pointer<Void> cookie) {}
void _cancelCb(Pointer<Void> cookie) {}

typedef _ReadFn =
    Pointer<
      NativeFunction<
        Int64 Function(Pointer<Void> cookie, Pointer<Uint8> buf, Uint64 nbytes)
      >
    >;
typedef _SeekFn =
    Pointer<NativeFunction<Int64 Function(Pointer<Void> cookie, Int64 offset)>>;
typedef _SizeFn = Pointer<NativeFunction<Int64 Function(Pointer<Void> cookie)>>;
typedef _VoidFn = Pointer<NativeFunction<Void Function(Pointer<Void> cookie)>>;

/// Index of the pointer-sized slot in [info] holding [value], or `-1`.
///
/// `mpv_stream_cb_info` is six consecutive pointers.
int _slotOf(Pointer<mpv_stream_cb_info> info, int value) {
  final words = info.cast<UintPtr>();
  for (var i = 0; i < 6; i++) {
    if (words[i] == value) {
      return i;
    }
  }
  return -1;
}

void main() {
  test('stream-cb-info-field-layout', () {
    final pointerSize = sizeOf<Pointer<Void>>();

    expect(sizeOf<mpv_stream_cb_info>(), 6 * pointerSize);

    final info = calloc<mpv_stream_cb_info>();
    addTearDown(() => calloc.free(info));

    // A swapped field is invisible through the field types, so the slots are
    // probed with distinct sentinels.
    info.ref.cookie = Pointer<Void>.fromAddress(0x11);
    info.ref.read_fn = _ReadFn.fromAddress(0x12);
    info.ref.seek_fn = _SeekFn.fromAddress(0x13);
    info.ref.size_fn = _SizeFn.fromAddress(0x14);
    info.ref.close_fn = _VoidFn.fromAddress(0x15);
    info.ref.cancel_fn = _VoidFn.fromAddress(0x16);

    expect(_slotOf(info, 0x11), 0);
    expect(_slotOf(info, 0x12), 1);
    expect(_slotOf(info, 0x13), 2);
    expect(_slotOf(info, 0x14), 3);
    expect(_slotOf(info, 0x15), 4);
    expect(_slotOf(info, 0x16), 5);

    expect(info.ref.cookie.address, 0x11);
    expect(info.ref.read_fn.address, 0x12);
    expect(info.ref.seek_fn.address, 0x13);
    expect(info.ref.size_fn.address, 0x14);
    expect(info.ref.close_fn.address, 0x15);
    expect(info.ref.cancel_fn.address, 0x16);
  });

  test('stream-cb-info-callback-slots', () {
    // The callables are never invoked — libmpv calls the real callback from
    // its own threads — they only pin the `int` slot signatures here, where
    // `-1` is the documented error return reported for Dart exceptions.
    final read =
        NativeCallable<
          Int64 Function(Pointer<Void>, Pointer<Uint8>, Uint64)
        >.isolateLocal(_readCb, exceptionalReturn: -1);
    final seek =
        NativeCallable<Int64 Function(Pointer<Void>, Int64)>.isolateLocal(
          _seekCb,
          exceptionalReturn: -1,
        );
    final size = NativeCallable<Int64 Function(Pointer<Void>)>.isolateLocal(
      _sizeCb,
      exceptionalReturn: -1,
    );
    final close = NativeCallable<Void Function(Pointer<Void>)>.isolateLocal(
      _closeCb,
    );
    final cancel = NativeCallable<Void Function(Pointer<Void>)>.isolateLocal(
      _cancelCb,
    );
    addTearDown(() {
      read.close();
      seek.close();
      size.close();
      close.close();
      cancel.close();
    });

    final info = calloc<mpv_stream_cb_info>();
    addTearDown(() => calloc.free(info));

    info.ref.cookie = nullptr;
    info.ref.read_fn = read.nativeFunction;
    info.ref.seek_fn = seek.nativeFunction;
    info.ref.size_fn = size.nativeFunction;
    info.ref.close_fn = close.nativeFunction;
    info.ref.cancel_fn = cancel.nativeFunction;

    expect(info.ref.cookie.address, 0);
    expect(info.ref.read_fn.address, read.nativeFunction.address);
    expect(info.ref.seek_fn.address, seek.nativeFunction.address);
    expect(info.ref.size_fn.address, size.nativeFunction.address);
    expect(info.ref.close_fn.address, close.nativeFunction.address);
    expect(info.ref.cancel_fn.address, cancel.nativeFunction.address);
  });
}
