import Foundation

enum CommandRunner {

    struct Result: Sendable {
        let output: String
        let exitCode: Int32
        let isError: Bool

        var isSuccess: Bool { exitCode == 0 }
    }

    static func run(shell command: String) async -> Result {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                let pipe = Pipe()

                process.executableURL = URL(fileURLWithPath: "/bin/zsh")
                process.arguments = ["-l", "-c", command]
                process.standardOutput = pipe
                process.standardError = pipe
                process.environment = ProcessInfo.processInfo.environment

                do {
                    try process.run()
                    process.waitUntilExit()

                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8) ?? ""

                    continuation.resume(returning: Result(
                        output: output.trimmingCharacters(in: .whitespacesAndNewlines),
                        exitCode: process.terminationStatus,
                        isError: process.terminationStatus != 0
                    ))
                } catch {
                    continuation.resume(returning: Result(
                        output: error.localizedDescription,
                        exitCode: -1,
                        isError: true
                    ))
                }
            }
        }
    }

    static func runAI(prompt: String) async -> Result {
        // Use claude CLI to process the AI prompt
        let escapedPrompt = prompt.replacingOccurrences(of: "'", with: "'\\''")
        let command = "claude -p '\(escapedPrompt)' --no-input 2>&1"
        return await run(shell: command)
    }
}
