/**
 * This file is a part of media_kit (https://github.com/media-kit/media-kit).
 * <p>
 * Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
 * All rights reserved.
 * Use of this source code is governed by MIT license that can be found in the LICENSE file.
 */
package com.alexmercerind.media_kit_video;

import android.util.Log;

import androidx.annotation.NonNull;
import io.flutter.view.TextureRegistry;

public class VideoOutput implements TextureRegistry.SurfaceProducer.Callback {
    private static final String TAG = "VideoOutput";

    private final TextureUpdateCallback callback;
    private final TextureRegistry.SurfaceProducer producer;

    private long id = 0;

    VideoOutput(@NonNull TextureRegistry registry, @NonNull TextureUpdateCallback callback) {
        this.callback = callback;
        this.producer = registry.createSurfaceProducer();
        this.producer.setCallback(this);
    }

    public void dispose() {
        try {
            callback.onTextureUpdate(id, null, producer.getWidth(), producer.getHeight());
        } catch (Throwable e) {
            Log.e(TAG, "dispose/callback", e);
        }
        try {
            producer.release();
        } catch (Throwable e) {
            Log.e(TAG, "dispose/release", e);
        }
    }

    public void setSurfaceSize(int width, int height) {
        try {
            if (producer.getWidth() == width && producer.getHeight() == height) {
                return;
            }
            producer.setSize(width, height);
            onSurfaceAvailable();
        } catch (Throwable e) {
            Log.e(TAG, "setSurfaceSize", e);
        }
    }

    @Override
    public void onSurfaceAvailable() {
        try {
            id = producer.id();
            callback.onTextureUpdate(id, producer.getSurface(), producer.getWidth(), producer.getHeight());
        } catch (Throwable e) {
            Log.e(TAG, "onSurfaceAvailable", e);
        }
    }

    @Override
    public void onSurfaceCleanup() {
        try {
            callback.onTextureUpdate(id, null, producer.getWidth(), producer.getHeight());
        } catch (Throwable e) {
            Log.e(TAG, "onSurfaceCleanup", e);
        }
    }
}
