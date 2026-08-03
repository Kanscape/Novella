import ExpoModulesCore
import Foundation

private final class RsOperationFailedException: Exception, @unchecked Sendable {
  let operation: String

  init(_ operation: String) {
    self.operation = operation
    super.init()
  }

  override var reason: String {
    "Novella Rust operation '\(operation)' failed"
  }
}

public final class NovellaRsModule: Module {
  public func definition() -> ModuleDefinition {
    Name("NovellaRs")

    AsyncFunction("convertWoff2ToTtf") { (data: Data) throws -> Data in
      guard let result = NovellaRsBridge.convertWoff2ToTtf(data) else {
        throw RsOperationFailedException("convertWoff2ToTtf")
      }
      return result
    }

    AsyncFunction("extractInvisibleCodepoints") { (data: Data) -> [Int] in
      NovellaRsBridge.extractInvisibleCodepoints(data).map { $0.intValue }
    }

  }
}
