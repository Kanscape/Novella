#import "NovellaRsBridge.h"

#import "../rust/include/novella_rs.h"

@implementation NovellaRsBridge

+ (NSData *)convertWoff2ToTtf:(NSData *)data {
  NovellaBuffer output = novella_rs_convert_woff2_to_ttf(
      static_cast<const uint8_t *>(data.bytes), data.length);
  if (output.ptr == NULL || output.len == 0) {
    novella_rs_free_buffer(output);
    return nil;
  }
  NSData *result = [NSData dataWithBytes:output.ptr length:output.len];
  novella_rs_free_buffer(output);
  return result;
}

+ (NSArray<NSNumber *> *)extractInvisibleCodepoints:(NSData *)data {
  NovellaBuffer output = novella_rs_extract_invisible_codepoints(
      static_cast<const uint8_t *>(data.bytes), data.length);
  NSMutableArray<NSNumber *> *result = [NSMutableArray array];
  const size_t count = output.len / sizeof(uint32_t);
  const uint32_t *values = (const uint32_t *)output.ptr;
  for (size_t index = 0; index < count; index++) {
    [result addObject:@(values[index])];
  }
  novella_rs_free_buffer(output);
  return result;
}


@end
