import Foundation

/// Version metadata for command-line tools and apps.
public struct CLIAppVersion: Sendable, Equatable {
  public let identifier: String?
  public let shortVersion: String?
  public let seconds: Int64?

  public init(identifier: String?, shortVersion: String?, seconds: Int64?) {
    self.identifier = identifier
    self.shortVersion = shortVersion
    self.seconds = seconds
  }

  /// Reads version information from the current process.
  ///
  /// The lookup strategy is:
  /// 1. Inspect the provided `bundleInfo` (default: `Bundle.main.infoDictionary`).
  /// 2. Fallback to a plist living alongside the executable (default: `<exec>.resources/Info.plist`).
  public static func read(
    bundleInfo: [String: Any]? = Bundle.main.infoDictionary,
    resourcesInfoPlistURLProvider: () -> URL? = { CLIAppVersion.resourcesInfoPlistURL() }
  ) -> CLIAppVersion {
    if let dict = bundleInfo {
      return CLIAppVersion(
        identifier: dict["CFBundleIdentifier"] as? String,
        shortVersion: dict["CFBundleShortVersionString"] as? String,
        seconds: (dict["CFBundleVersion"] as? String).flatMap(Int64.init)
      )
    }

    if let url = resourcesInfoPlistURLProvider(),
      let dict = try? readPlist(at: url)
    {
      return CLIAppVersion(
        identifier: dict["CFBundleIdentifier"] as? String,
        shortVersion: dict["CFBundleShortVersionString"] as? String,
        seconds: (dict["CFBundleVersion"] as? String).flatMap(Int64.init)
      )
    }

    return CLIAppVersion(identifier: nil, shortVersion: nil, seconds: nil)
  }

  // MARK: - Internals for testing / overrides

  static func readPlist(at url: URL) throws -> [String: Any] {
    let data = try Data(contentsOf: url)
    var format = PropertyListSerialization.PropertyListFormat.xml
    return try PropertyListSerialization.propertyList(from: data, options: [], format: &format)
      as? [String: Any] ?? [:]
  }

  public static func resourcesInfoPlistURL(
    executableURLProvider: () -> URL? = { CLIAppVersion.executableURL() }
  ) -> URL? {
    guard let execURL = executableURLProvider() else { return nil }
    let resourcesDirectory =
      execURL
      .deletingLastPathComponent()
      .appendingPathComponent(execURL.lastPathComponent + ".resources", isDirectory: true)
    let plist = resourcesDirectory.appendingPathComponent("Info.plist")
    return FileManager.default.fileExists(atPath: plist.path) ? plist : nil
  }

  public static func executableURL(
    arguments: [String] = CommandLine.arguments,
    fileManager: FileManager = .default
  ) -> URL? {
    #if os(Linux)
    // /proc/self/exe is a symlink to the running executable on Linux.
    let procPath = "/proc/self/exe"
    var buffer = [Int8](repeating: 0, count: 4096)
    let length = readlink(procPath, &buffer, buffer.count)
    if length > 0,
      let resolved = String(
        bytesNoCopy: &buffer, length: Int(length), encoding: .utf8, freeWhenDone: false)
    {
      return URL(fileURLWithPath: resolved).resolvingSymlinksInPath()
    }
    #endif

    if let bundleURL = Bundle.main.executableURL {
      return bundleURL
    }

    guard let firstArg = arguments.first else {
      return nil
    }

    if firstArg.hasPrefix("/") {
      return URL(fileURLWithPath: firstArg).resolvingSymlinksInPath()
    }

    return URL(fileURLWithPath: fileManager.currentDirectoryPath)
      .appendingPathComponent(firstArg)
      .resolvingSymlinksInPath()
  }
}

public enum CLIAppVersionReader {
  /// Creates a version payload from epoch seconds and optional identifier.
  /// The short version string is rendered as `yy.MM.dd` in the current locale.
  public static func make(seconds: Int64, identifier: String? = nil) -> CLIAppVersion {
    let date = Date(timeIntervalSince1970: TimeInterval(seconds))
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .iso8601)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = .current
    formatter.dateFormat = "yy.MM.dd"
    let short = formatter.string(from: date)
    return CLIAppVersion(identifier: identifier, shortVersion: short, seconds: seconds)
  }
}
