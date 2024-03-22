#include "yume_audio.h"
#include <vorbis/vorbisfile.h>

using namespace oboe;

auto yume_audio_init(const char *path) -> Player * {
  auto player = new Player;
  ov_fopen(path, &player->vf);
  return player;
}

void yume_audio_play(Player *player) {
  AudioStreamBuilder builder;
  builder.setPerformanceMode(PerformanceMode::LowLatency)
      ->setSharingMode(SharingMode::Exclusive)
      ->setDataCallback(std::make_shared<PlayerDataCallback>(player))
      ->setFormat(AudioFormat::Float)
      ->setChannelCount(ChannelCount::Stereo);

  std::shared_ptr<AudioStream> stream;
  auto res = builder.openStream(stream);
  if (res != Result::OK) {
    return;
  }
}

void yume_audio_set_pitch(Player *player, float pitch) {
  player->pitch = pitch;
}

auto PlayerDataCallback::onAudioReady(AudioStream *audioStream, void *audioData,
                                      int32_t numFrames) -> DataCallbackResult {
  auto player = this->player;
  auto vf = &player->vf;
  auto *outptr = static_cast<float **>(audioData);
  int current_section;
  ov_read_float(vf, this->buffer, numFrames, &current_section);

  stretch.reset();
  stretch.configure(2, 4096, 4096);
  stretch.setTransposeFactor(player->pitch);
  stretch.process(&this->buffer, numFrames, &outptr, numFrames);

  return DataCallbackResult::Continue;
}