#include <jni.h>

#include <cstdint>
#include <cstring>
#include <string>
#include <vector>

#include "novella_rs.h"

namespace {

jbyteArray toByteArray(JNIEnv *env, NovellaBuffer buffer) {
  if (buffer.ptr == nullptr || buffer.len == 0) {
    novella_rs_free_buffer(buffer);
    return env->NewByteArray(0);
  }
  auto result = env->NewByteArray(static_cast<jsize>(buffer.len));
  env->SetByteArrayRegion(result, 0, static_cast<jsize>(buffer.len),
                          reinterpret_cast<const jbyte *>(buffer.ptr));
  novella_rs_free_buffer(buffer);
  return result;
}

jintArray toIntArray(JNIEnv *env, NovellaBuffer buffer) {
  const auto count = buffer.len / sizeof(uint32_t);
  auto result = env->NewIntArray(static_cast<jsize>(count));
  if (result != nullptr && count != 0) {
    std::vector<jint> values(count);
    for (size_t index = 0; index < count; ++index) {
      uint32_t value = 0;
      std::memcpy(&value, buffer.ptr + index * sizeof(uint32_t), sizeof(value));
      values[index] = static_cast<jint>(value);
    }
    env->SetIntArrayRegion(result, 0, static_cast<jsize>(count), values.data());
  }
  novella_rs_free_buffer(buffer);
  return result;
}

} // namespace

extern "C" JNIEXPORT jbyteArray JNICALL
Java_sh_celia_novella_modules_novellars_NovellaRsBridge_convertWoff2ToTtf(
    JNIEnv *env, jobject, jbyteArray data) {
  const auto length = env->GetArrayLength(data);
  std::vector<jbyte> input(length);
  env->GetByteArrayRegion(data, 0, length, input.data());
  return toByteArray(env, novella_rs_convert_woff2_to_ttf(
      reinterpret_cast<const uint8_t *>(input.data()), input.size()));
}

extern "C" JNIEXPORT jintArray JNICALL
Java_sh_celia_novella_modules_novellars_NovellaRsBridge_extractInvisibleCodepoints(
    JNIEnv *env, jobject, jbyteArray data) {
  const auto length = env->GetArrayLength(data);
  std::vector<jbyte> input(length);
  env->GetByteArrayRegion(data, 0, length, input.data());
  return toIntArray(env, novella_rs_extract_invisible_codepoints(
      reinterpret_cast<const uint8_t *>(input.data()), input.size()));
}

