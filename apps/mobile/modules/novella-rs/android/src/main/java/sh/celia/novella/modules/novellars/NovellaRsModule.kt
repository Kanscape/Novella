package sh.celia.novella.modules.novellars

import expo.modules.kotlin.exception.CodedException
import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition

private class RsOperationFailedException(operation: String) :
  CodedException("Novella Rust operation '$operation' failed")

class NovellaRsModule : Module() {
  override fun definition() = ModuleDefinition {
    Name("NovellaRs")

    AsyncFunction("convertWoff2ToTtf") { data: ByteArray ->
      NovellaRsBridge.convertWoff2ToTtf(data).also {
        if (it.isEmpty()) throw RsOperationFailedException("convertWoff2ToTtf")
      }
    }

    AsyncFunction("extractInvisibleCodepoints") { data: ByteArray ->
      NovellaRsBridge.extractInvisibleCodepoints(data).toList()
    }

  }
}
