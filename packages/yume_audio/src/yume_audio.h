#pragma once

#if _WIN32
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FFI_PLUGIN_EXPORT                                                      \
  __attribute__((visibility("default"))) __attribute__((used))
#endif

#if __cplusplus

#if _WIN32
#include <windows.h>
typedef struct _AudioStream AudioStream;
#else
#include <oboe/Oboe.h>
#include <pthread.h>
#include <unistd.h>
using namespace oboe;
#endif

#ifndef defer
struct defer_dummy {};
template <class F> struct deferrer {
  F f;
  ~deferrer() { f(); }
};
template <class F> deferrer<F> operator*(defer_dummy, F f) { return {f}; }
#define DEFER_(LINE) zz_defer##LINE
#define DEFER(LINE) DEFER_(LINE)
#define defer auto DEFER(__LINE__) = defer_dummy{} *[&]()
#endif // defer

#else
typedef struct _AudioStream AudioStream;
#endif // __cplusplus

#if __cplusplus
extern "C" {
#endif

typedef enum { pause_stream, start_stream, stop_stream } StreamStatus;

typedef struct {
  float pitch;
} PlayOptions;

/// [pitch] is a multiplier value where 1.0 is the original pitch.
FFI_PLUGIN_EXPORT AudioStream *play_with_pitch(char *input_path, float pitch);

// Once called, the stream will be disposed and the audio will stop playing.
FFI_PLUGIN_EXPORT void dispose_stream(AudioStream *stream);

FFI_PLUGIN_EXPORT void set_pitch(AudioStream *stream, float pitch);

/// Pass [StreamStatus] to change the state of the stream.
FFI_PLUGIN_EXPORT void request_state_change(AudioStream *stream,
                                            StreamStatus state);

typedef struct {
  int32_t sample_rate;
  int32_t bit_rate;
  int32_t channel_mask;
  int32_t channels;
  int32_t bytes_written;
} DecodeResult;

static std::optional<DecodeResult> decode(const char *__restrict input_path,
                                          uint8_t *__restrict target_data);
#if __cplusplus
} // extern "C"
#endif