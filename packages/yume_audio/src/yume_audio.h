#pragma once

#if _WIN32
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FFI_PLUGIN_EXPORT __attribute__((visibility("default"))) __attribute__((used))
#endif

#if __cplusplus
#include "signalsmith-stretch.h"
#include <fstream>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#if _WIN32
#include <windows.h>
#else
#include <oboe/Oboe.h>
#include <pthread.h>
#include <unistd.h>
#include <vorbis/vorbisfile.h>

#endif

using namespace oboe;

class Player {
public:
  float pitch = 1;
  OggVorbis_File vf;
};

class PlayerDataCallback : public oboe::AudioStreamDataCallback {
public:
  Player *player;
  float **buffer[4096];
  signalsmith::stretch::SignalsmithStretch<> stretch;
  PlayerDataCallback(Player *player) { this->player = player; }
  DataCallbackResult onAudioReady(AudioStream *audioStream, void *audioData, int32_t numFrames) override;
};
#else
typedef struct _Player Player;
#endif

FFI_PLUGIN_EXPORT Player *yume_audio_init(const char *path);
FFI_PLUGIN_EXPORT void yume_audio_play(Player *player);
FFI_PLUGIN_EXPORT void yume_audio_set_pitch(Player *player, float pitch);
