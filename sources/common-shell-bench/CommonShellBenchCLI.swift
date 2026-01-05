import ArgumentParser

@main
struct CommonShellBench: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "common-shell-bench",
    abstract: "Benchmark CommonShell host × runner matrix over simple workloads",
    subcommands: [Matrix.self, Metrics.self],
    defaultSubcommand: Matrix.self,
  )
}
