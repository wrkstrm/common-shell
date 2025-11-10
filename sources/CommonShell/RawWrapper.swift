public enum RawWrapper: Sendable, Equatable {
  case direct
  case shell
  case env(String)
}
