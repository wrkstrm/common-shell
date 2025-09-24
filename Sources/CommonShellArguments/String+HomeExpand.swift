import Foundation

// Minimal helper to expand '~' in user-provided paths.
extension String {
  public func homeExpandedString() -> String { (self as NSString).expandingTildeInPath }
}
