package com.alexmercerind.media_kit_video;

import androidx.annotation.Nullable;

public interface TextureUpdateCallback {
    /**
     * @param id      Flutter texture id
     * @param surface android.view.Surface (null if cleaned up)
     * @param width   surface width
     * @param height  surface height
     */
    void onTextureUpdate(long id, @Nullable Object surface, int width, int height);
}