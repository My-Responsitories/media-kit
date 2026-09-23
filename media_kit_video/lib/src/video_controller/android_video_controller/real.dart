/// This file is a part of media_kit (https://github.com/media-kit/media-kit).
///
/// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
/// All rights reserved.
/// Use of this source code is governed by MIT license that can be found in the LICENSE file.
import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:jni/jni.dart';
import 'package:media_kit_video/src/utils/android/bindings.g.dart';

import 'package:media_kit/media_kit.dart';

import 'package:media_kit_video/src/video_controller/platform_video_controller.dart';

/// {@template android_video_controller}
///
/// AndroidVideoController
/// ----------------------
///
/// The [PlatformVideoController] implementation based on native JNI & C/C++ used on Android.
///
/// {@endtemplate}
class AndroidVideoController extends PlatformVideoController {
  /// Whether [AndroidVideoController] is supported on the current platform or not.
  static bool get supported => Platform.isAndroid;

  late final VideoOutput videoOutput;

  /// Holds a JNI global reference to the current `android.view.Surface`.
  JObject? _surface;

  /// [StreamSubscription] for listening to video [VideoParams].
  late final StreamSubscription<VideoParams> videoParamsSubscription;

  void setProperties(Map<String, String> properties) {
    for (final entry in properties.entries) {
      player.setProperty(entry.key, entry.value);
    }
  }

  /// Called synchronously by Java on the Flutter UI isolate (Android main
  /// thread). By the time [VideoOutputManager.create] / [VideoOutputManager.setSurfaceSize]
  /// returns, [wid] is guaranteed to have been updated.
  void _onTextureUpdate(
    int textureId,
    JObject? surface,
    int width,
    int height,
  ) {
    debugPrint(
      'media-kit: _onTextureUpdate(textureId=$textureId, surface=$surface, width=$width, height=$height)',
    );
    if (surface != null) {
      player.setProperty('vo', 'null');
      setProperties({
        // ORDER IS IMPORTANT.
        'android-surface-size': '${width}x$height',
        // ignore: invalid_use_of_internal_member
        'wid': surface.reference.pointer.address.toString(),
        // When --wid is 0, vo=null is required to avoid SIGSEGV.
        'vo': configuration.vo ?? 'gpu',
        // It is important to re-initialize --vid in-case of --vo=mediacodec_embed after --android-surface-size.
        // Not doing so causes error "Could not open codec." & video never gets rendered.
        if (configuration.vo == 'mediacodec_embed') 'vid': 'auto',
      });
      _surface?.release();
      _surface = surface;
    } else {
      _surface?.release();
      _surface = null;
      setProperties({
        'vo': 'null',
        'wid': '0',
        if (configuration.vo == 'mediacodec_embed') 'vid': 'no',
      });
    }

    id.value = textureId;
    size.value = (width, height);
  }

  /// {@macro android_video_controller}
  AndroidVideoController._(super.player, super.configuration) {
    setProperties({
      'hwdec':
          configuration.hwdec ??
          (configuration.enableHardwareAcceleration ? 'auto-safe' : 'no'),
      'vid': 'auto',
      'opengl-es': 'yes',
      'force-window': 'yes',
      'gpu-context': 'android',
      'sub-use-margins': 'no',
      'sub-font-provider': 'none',
      'sub-scale-with-window': 'yes',
      'hwdec-codecs': 'h264,hevc,mpeg4,mpeg2video,vp8,vp9,av1',
    });

    // Register the Java callback *before* creating the native output.
    // `onTextureUpdate$async` is left at its default (`false`), i.e. the
    // callback runs synchronously on the calling thread - which is exactly
    // what we want here.
    final callback = TextureUpdateCallback.implement(
      $TextureUpdateCallback(onTextureUpdate: _onTextureUpdate),
    );

    videoOutput = VideoOutput(callback);
    callback.release();

    videoParamsSubscription = player.stream.videoParams.listen((event) {
      final int width, height;
      if (event.rotate == 0 || event.rotate == 180) {
        width = event.dw ?? 0;
        height = event.dh ?? 0;
      } else {
        // width & height are swapped for 90 or 270 degrees rotation.
        width = event.dh ?? 0;
        height = event.dw ?? 0;
      }

      late final size = this.size.value;
      if (width == 0 ||
          height == 0 ||
          (size != null && width == size.$1 && height == size.$2)) {
        return;
      }

      videoOutput.setSurfaceSize(width, height);

      if (!waitUntilFirstFrameRenderedCompleter.isCompleted) {
        waitUntilFirstFrameRenderedCompleter.complete();
      }
    });
  }

  /// {@macro android_video_controller}
  static FutureOr<PlatformVideoController> create(
    Player player,
    VideoControllerConfiguration configuration,
  ) {
    // Retrieve the native handle of the [Player].
    final handle = player.handle;
    // Return the existing [VideoController] if it's already created.
    if (_controllers[handle] case final ctr?) {
      return ctr;
    }

    // Creation:
    final controller = AndroidVideoController._(player, configuration);

    // Register [_dispose] for execution upon [Player.dispose].
    player.release.add(controller.dispose);

    // Store the [VideoController] in the [_controllers].
    _controllers[handle] = controller;

    return controller;
  }

  /// Sets the required size of the video output.
  /// This may yield substantial performance improvements if a small [width] & [height] is specified.
  ///
  /// Remember:
  /// * “Premature optimization is the root of all evil”
  /// * “With great power comes great responsibility”
  @override
  Future<void> setSize({int? width, int? height}) {
    throw UnsupportedError(
      '[AndroidVideoController.setSize] is not available on Android',
    );
  }

  /// Disposes the instance. Releases allocated resources back to the system.
  @override
  Future<void> dispose() async {
    super.dispose();
    await videoParamsSubscription.cancel();
    final handle = player.handle;
    _controllers.remove(handle);

    videoOutput.dispose();

    _surface?.release();
    _surface = null;
  }

  /// Currently created [AndroidVideoController]s.
  static final _controllers = HashMap<int, AndroidVideoController>();
}
