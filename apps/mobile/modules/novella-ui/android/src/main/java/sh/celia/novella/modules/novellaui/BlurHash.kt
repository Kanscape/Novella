package sh.celia.novella.modules.novellaui

import android.graphics.Bitmap
import androidx.compose.foundation.Image
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import expo.modules.kotlin.views.ComposeProps
import expo.modules.kotlin.views.FunctionalComposableScope
import expo.modules.kotlin.views.OptimizedComposeProps
import expo.modules.ui.ModifierList
import expo.modules.ui.ModifierRegistry

@OptimizedComposeProps
data class BlurHashProps(
  val blurHash: String = "",
  val width: Int = 32,
  val height: Int = 48,
  val modifiers: ModifierList = emptyList()
) : ComposeProps

@Composable
fun FunctionalComposableScope.BlurHashContent(props: BlurHashProps) {
  val width = props.width.coerceIn(1, 128)
  val height = props.height.coerceIn(1, 128)
  val bitmap = remember(props.blurHash, width, height) {
    // Expo Image's Android cosine cache is keyed only by dimension * component
    // count. Different dimension/component pairs can collide and produce black
    // bands. Keep Expo's native decoder but bypass that unsafe global cache for
    // these tiny placeholders.
    decodeWithExpoImage(props.blurHash, width, height)
  }
  if (bitmap != null) {
    Image(
      bitmap = bitmap.asImageBitmap(),
      contentDescription = null,
      contentScale = ContentScale.Crop,
      modifier = ModifierRegistry.applyModifiers(
        props.modifiers,
        appContext,
        composableScope,
        globalEventDispatcher
      )
    )
  }
}

private fun decodeWithExpoImage(blurHash: String, width: Int, height: Int): Bitmap? =
  runCatching {
    // expo-image is autolinked into Expo's aggregated Android module and is not
    // available as a separate Gradle project dependency in SDK 57. Resolve its
    // bundled decoder at runtime so this adapter can select useCache=false
    // without copying the BlurHash algorithm or moving pixels through JS.
    val decoderClass = Class.forName("expo.modules.image.blurhash.BlurhashDecoder")
    val decoder = decoderClass.getField("INSTANCE").get(null)
    val decode = decoderClass.getMethod(
      "decode",
      String::class.java,
      Int::class.javaPrimitiveType,
      Int::class.javaPrimitiveType,
      Float::class.javaPrimitiveType,
      Boolean::class.javaPrimitiveType
    )
    decode.invoke(decoder, blurHash, width, height, 1f, false) as? Bitmap
  }.getOrNull()
