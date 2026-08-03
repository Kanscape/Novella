package sh.celia.novella.modules.novellars

internal object NovellaRsBridge {
  init {
    System.loadLibrary("novella_rs_bridge")
  }

  external fun convertWoff2ToTtf(data: ByteArray): ByteArray

  external fun extractInvisibleCodepoints(data: ByteArray): IntArray

}
