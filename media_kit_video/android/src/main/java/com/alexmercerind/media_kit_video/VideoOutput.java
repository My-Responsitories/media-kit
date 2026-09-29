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
import androidx.annotation.Nullable;
import io.flutter.view.TextureRegistry;

public class VideoOutput implements TextureRegistry.SurfaceProducer.Callback {
    private static final String TAG = "VideoOutput";
    private static TextureRegistry textureRegistry;

    private final TextureUpdateCallback callback;
    private final TextureRegistry.SurfaceProducer producer;

    public VideoOutput(@NonNull TextureUpdateCallback callback) {
        if (textureRegistry == null) {
            throw new IllegalStateException("TextureRegistry not set");
        }
        this.callback = callback;
        producer = textureRegistry.createSurfaceProducer();
        producer.setCallback(this);
    }

    static void setTextureRegistry(@Nullable TextureRegistry registry) {
        textureRegistry = registry;
    }

    public void dispose() {
        onSurfaceCleanup();
        try {
            producer.release();
        } catch (Throwable e) {
            Log.e(TAG, "dispose/release", e);
        }
    }

    public void setSurfaceSize(int width, int height) {
        try {
            producer.setSize(width, height);
            onSurfaceAvailable();
        } catch (Throwable e) {
            Log.e(TAG, "setSurfaceSize", e);
        }
    }

    @Override
    public void onSurfaceAvailable() {
        try {
            callback.onTextureUpdate(producer.id(), producer.getSurface(), producer.getWidth(), producer.getHeight());
        } catch (Throwable e) {
            Log.e(TAG, "onSurfaceAvailable", e);
        }
    }

    @Override
    public void onSurfaceCleanup() {
        try {
            callback.onTextureUpdate(producer.id(), null, producer.getWidth(), producer.getHeight());
        } catch (Throwable e) {
            Log.e(TAG, "onSurfaceCleanup", e);
        }
    }
}
