/**
 * This file is a part of media_kit (https://github.com/media-kit/media-kit).
 * <p>
 * Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
 * All rights reserved.
 * Use of this source code is governed by MIT license that can be found in the LICENSE file.
 */
package com.alexmercerind.media_kit_video;

import android.util.Log;

import java.util.HashMap;
import java.util.Locale;
import java.util.Map;

import androidx.annotation.Keep;
import androidx.annotation.NonNull;
import io.flutter.view.TextureRegistry;

@Keep
public class VideoOutputManager {
    private static final String TAG = "VideoOutputManager";

    private static final Map<Long, VideoOutput> outputs = new HashMap<>();
    private static TextureRegistry textureRegistry;

    /** Called from MediaKitVideoPlugin.onAttachedToEngine. */
    static void initialize(@NonNull TextureRegistry registry) {
        textureRegistry = registry;
    }

    public static void create(long handle, @NonNull TextureUpdateCallback callback) {
        if (textureRegistry == null) {
            throw new IllegalStateException("TextureRegistry not initialized");
        }
        if (!outputs.containsKey(handle)) {
            Log.i(TAG, String.format(Locale.ENGLISH, "create: %d", handle));
            outputs.put(handle, new VideoOutput(textureRegistry, callback));
        } else {
            throw new IllegalStateException("VideoOutput initialized");
        }
    }

    public static void setSurfaceSize(long handle, int width, int height) {
        final VideoOutput output = outputs.get(handle);
        if (output != null) {
            output.setSurfaceSize(width, height);
        }
    }

    public static void dispose(long handle) {
        final VideoOutput output = outputs.remove(handle);
        if (output != null) {
            Log.i(TAG, String.format(Locale.ENGLISH, "dispose: %d", handle));
            output.dispose();
        }
    }

    static void disposeAll() {
        for (final VideoOutput output : outputs.values()) {
            output.dispose();
        }
        outputs.clear();
        textureRegistry = null;
    }
}
