#ifndef NOVELLA_RS_H
#define NOVELLA_RS_H

#include <stddef.h>
#include <stdint.h>

typedef struct {
  uint8_t *ptr;
  size_t len;
} NovellaBuffer;

#ifdef __cplusplus
extern "C" {
#endif

NovellaBuffer novella_rs_convert_woff2_to_ttf(const uint8_t *data, size_t len);
NovellaBuffer novella_rs_extract_invisible_codepoints(const uint8_t *data, size_t len);
void novella_rs_free_buffer(NovellaBuffer buffer);

#ifdef __cplusplus
}
#endif

#endif
