#include "yume_audio.h"
#include "oboe/AudioStream.h"
#include "signalsmith-stretch.h"
#include <android/log.h>
#include <cstdint>
#include <cstdio>
#include <media/NdkMediaError.h>
#include <media/NdkMediaExtractor.h>
#include <media/NdkMediaFormat.h>
#include <memory>

// #include <vector>

using namespace oboe;

#ifndef SOURCE_PATH_SIZE
#define SOURCE_PATH_SIZE 0
#endif

#define STRINGIFY(x) #x
#define FORMAT_LINE(FILE, LINE)                                                \
  ((__FILE__ ":" STRINGIFY(LINE)) + (SOURCE_PATH_SIZE))
#define DEBUG(...)                                                             \
  __android_log_print(ANDROID_LOG_DEBUG, FORMAT_LINE(__FILE__, __LINE__),      \
                      __VA_ARGS__)
#define ERROR(...)                                                             \
  __android_log_print(ANDROID_LOG_ERROR, FORMAT_LINE(__FILE__, __LINE__),      \
                      __VA_ARGS__)

template <size_t buffer_len = 256>
class Callback : public oboe::AudioStreamDataCallback {
  using Buffer = std::vector<uint8_t>;

public:
  Buffer buffer;
  float pitch = 1.0;
  uint32_t frame_index = 0;
  Buffer audio_data;
  DecodeResult info;
  signalsmith::stretch::SignalsmithStretch<> stretch;

  Callback(DecodeResult &info, Buffer &&buffer, float pitch)
      : buffer(std::move(buffer)), pitch(pitch), info(info) {
    stretch.presetDefault(info.channels, info.sample_rate);
    stretch.setTransposeFactor(pitch);
  }

  auto onAudioReady(AudioStream *audioStream, void *audioData,
                    int32_t numFrames) -> DataCallbackResult override {
    float framebuffer[buffer_len][2], output_buffer[buffer_len][2];
    size_t max_frames = std::min((size_t)numFrames, buffer_len);
    auto pcm_buffer = reinterpret_cast<int16_t *>(buffer.data());
    auto pcm_buffer_size = buffer.size() / sizeof(int16_t);

    for (size_t frame = 0; frame < max_frames; frame += info.channels) {
      for (size_t channel = 0; channel < info.channels; channel++) {
        framebuffer[frame][channel] =
            pcm_buffer[frame_index + channel] / 32767.0;
      }
      frame_index = (frame_index + info.channels) % pcm_buffer_size;
    }
    stretch.process(framebuffer, max_frames, output_buffer, max_frames);
    auto *outptr = static_cast<int16_t *>(audioData);
    for (size_t frame = 0; frame < max_frames; frame++) {
      for (size_t channel = 0; channel < info.channels; channel++) {
        outptr[frame * info.channels + channel] =
            output_buffer[frame][channel] * 32767;
      }
    }

    return DataCallbackResult::Continue;
  }
};

template <class T> T *leak_shared(std::shared_ptr<T> &&ptr) {
  struct LeakDeleter {
    void operator()(void *ptr) {}
  };
  std::shared_ptr<T> leak_ptr(nullptr, LeakDeleter{});
  leak_ptr.swap(ptr);
  return leak_ptr.get();
}

template <class T> std::shared_ptr<T> reclaim_shared(T *ptr) {
  return std::shared_ptr<T>(ptr);
}

constexpr int max_compression_ratio = 12;

AudioStream *play_with_pitch(char *input_path, float pitch) {
  defer { free(input_path); };

  const long buffer_size =
      max_compression_ratio * (4 * 1024 * 1024) * sizeof(int16_t);
  // auto buffer = std::make_unique<uint8_t>(buffer_size);
  auto buffer = std::vector<uint8_t>(buffer_size);
  auto info = decode(input_path, buffer.data());
  if (!info || info->bytes_written < 0) {
    return nullptr;
  }

  AudioStreamBuilder builder;
  builder.setPerformanceMode(PerformanceMode::LowLatency)
      ->setFormat(AudioFormat::Float)
      ->setChannelCount(info->channels)
      ->setSampleRate(info->sample_rate)
      ->setBufferCapacityInFrames(256)
      ->setDataCallback(
          std::make_shared<Callback<>>(info.value(), std::move(buffer), pitch));

  std::shared_ptr<AudioStream> stream;
  if (builder.openStream(stream) != Result::OK) {
    return nullptr;
  }
  stream->requestStart();
  return leak_shared(std::move(stream));
}

void dispose_stream(AudioStream *ptr) {
  auto stream = reclaim_shared(ptr);
  stream->release();
}

void set_pitch(AudioStream *stream, float pitch) {
  auto callback = static_cast<Callback<> *>(stream->getDataCallback());
  callback->stretch.setTransposeFactor(pitch);
}

void request_state_change(AudioStream *stream, StreamStatus state) {
  switch (state) {
  case pause_stream:
    stream->requestPause();
    break;
  case start_stream:
    stream->requestStart();
    break;
  case stop_stream:
    stream->requestStop();
    break;
  }
}

auto decode(const char *__restrict input_path, uint8_t *__restrict target_data)
    -> std::optional<DecodeResult> {
  media_status_t result;
  DecodeResult info;

  auto *file = fopen(input_path, "rb");
  if (!file) {
    ERROR("Failed to open file %s", input_path);
    return {};
  }
  defer { fclose(file); };

  auto *extractor = AMediaExtractor_new();
  defer { AMediaExtractor_delete(extractor); };

  result = AMediaExtractor_setDataSourceFd(extractor, fileno(file), 0,
                                           std::numeric_limits<int64_t>::max());
  if (result != AMEDIA_OK) {
    ERROR("Error setting extractor data source, err %d", result);
    return {};
  }

  auto *format = AMediaExtractor_getTrackFormat(extractor, 0);
  defer { AMediaFormat_delete(format); };

  if (AMediaFormat_getInt32(format, AMEDIAFORMAT_KEY_SAMPLE_RATE,
                            &info.sample_rate)) {
    DEBUG("Source sample rate %d", info.sample_rate);
  } else {
    ERROR("Failed to get sample rate");
    return {};
  }

  int32_t bit_rate;
  if (AMediaFormat_getInt32(format, AMEDIAFORMAT_KEY_BIT_RATE, &bit_rate)) {
    DEBUG("Source bit rate %d", bit_rate);
  } else {
    ERROR("Failed to get bit rate");
    return {};
  }

  if (AMediaFormat_getInt32(format, AMEDIAFORMAT_KEY_CHANNEL_COUNT,
                            &info.channels)) {
    DEBUG("Got channel count %d", info.channels);
  } else {
    ERROR("Failed to get channel count");
    return {};
  }

  if (info.channels > 2) {
    ERROR("Unsupported channel count %d", info.channels);
    return {};
  }

  const char *media_format = AMediaFormat_toString(format);
  DEBUG("Output format %s", media_format);

  const char *mimeType;
  if (AMediaFormat_getString(format, AMEDIAFORMAT_KEY_MIME, &mimeType)) {
    DEBUG("Got mime type %s", mimeType);
  } else {
    ERROR("Failed to get mime type");
    return {};
  }

  enum {
    /// [-32768, 32767],
    ENCODING_PCM_16BIT = 0x2,
    ENCODING_PCM_8BIT = 0x3,
    ENCODING_PCM_FLOAT = 0x4,
    ENCODING_PCM_24BIT_PACKED = 0x15,
    ENCODING_PCM_32BIT = 0x16,
  };

  if (!AMediaFormat_getInt32(format, AMEDIAFORMAT_KEY_CHANNEL_MASK,
                             &info.channel_mask)) {
    info.channel_mask = 0;
  }

  AMediaExtractor_selectTrack(extractor, 0);
  auto *codec = AMediaCodec_createDecoderByType(mimeType);
  defer { AMediaCodec_delete(codec); };
  AMediaCodec_configure(codec, format, nullptr, nullptr, 0);
  AMediaCodec_start(codec);

  // DECODE

  bool isExtracting = true;
  bool isDecoding = true;
  int32_t bytesWritten = 0;

  while (isExtracting || isDecoding) {

    if (isExtracting) {

      // Obtain the index of the next available input buffer
      ssize_t inputIndex = AMediaCodec_dequeueInputBuffer(codec, 2000);
      // LOGV("Got input buffer %d", inputIndex);

      // The input index acts as a status if its negative
      if (inputIndex < 0) {
        if (inputIndex == AMEDIACODEC_INFO_TRY_AGAIN_LATER) {
          // LOGV("Codec.dequeueInputBuffer try again later");
        } else {
          ERROR("Codec.dequeueInputBuffer unknown error status");
        }
      } else {

        // Obtain the actual buffer and read the encoded data into it
        size_t inputSize;
        uint8_t *inputBuffer =
            AMediaCodec_getInputBuffer(codec, inputIndex, &inputSize);
        // LOGV("Sample size is: %d", inputSize);

        ssize_t sampleSize =
            AMediaExtractor_readSampleData(extractor, inputBuffer, inputSize);
        auto presentationTimeUs = AMediaExtractor_getSampleTime(extractor);

        if (sampleSize > 0) {

          // Enqueue the encoded data
          AMediaCodec_queueInputBuffer(codec, inputIndex, 0, sampleSize,
                                       presentationTimeUs, 0);
          AMediaExtractor_advance(extractor);

        } else {
          DEBUG("End of extractor data stream");
          isExtracting = false;

          // We need to tell the codec that we've reached the end
          // of the stream
          AMediaCodec_queueInputBuffer(codec, inputIndex, 0, 0,
                                       presentationTimeUs,
                                       AMEDIACODEC_BUFFER_FLAG_END_OF_STREAM);
        }
      }
    }

    if (isDecoding) {
      // Dequeue the decoded data
      AMediaCodecBufferInfo info;
      ssize_t outputIndex = AMediaCodec_dequeueOutputBuffer(codec, &info, 0);

      if (outputIndex >= 0) {

        // Check whether this is set earlier
        if (info.flags & AMEDIACODEC_BUFFER_FLAG_END_OF_STREAM) {
          DEBUG("Reached end of decoding stream");
          isDecoding = false;
        }

        // Valid index, acquire buffer
        size_t outputSize;
        uint8_t *outputBuffer =
            AMediaCodec_getOutputBuffer(codec, outputIndex, &outputSize);

        /*LOGV("Got output buffer index %d, buffer size: %d, info
        size: %d writing to pcm index %d",
             outputIndex,
             outputSize,
             info.size,
             m_writeIndex);*/

        // copy the data out of the buffer
        memcpy(target_data + bytesWritten, outputBuffer, info.size);
        bytesWritten += info.size;
        AMediaCodec_releaseOutputBuffer(codec, outputIndex, false);
      } else {
        // The outputIndex doubles as a status return if its value is < 0
        switch (outputIndex) {
        case AMEDIACODEC_INFO_TRY_AGAIN_LATER:
          DEBUG("dequeueOutputBuffer: try again later");
          break;
        case AMEDIACODEC_INFO_OUTPUT_BUFFERS_CHANGED:
          DEBUG("dequeueOutputBuffer: output buffers changed");
          break;
        case AMEDIACODEC_INFO_OUTPUT_FORMAT_CHANGED:
          DEBUG("dequeueOutputBuffer: output outputFormat changed");
          format = AMediaCodec_getOutputFormat(codec);
          DEBUG("outputFormat changed to: %s", AMediaFormat_toString(format));
          break;
        }
      }
    }
  }

  return info;
}
