import Foundation

public struct ShellOutput {
    public let stdout: String
    public let stderr: String
    public let exitCode: Int32
    public var succeeded: Bool { exitCode == 0 }
}

public struct Shell {
    /// Run a shell command string via zsh.
    @discardableResult
    public static func run(
        _ command: String,
        input: String? = nil,
        workingDirectory: String? = nil
    ) -> ShellOutput {
        return runArgs(["/bin/zsh", "-c", command], input: input, workingDirectory: workingDirectory)
    }

    /// Run a command with explicit argument array (avoids shell quoting issues for sensitive values).
    @discardableResult
    public static func runArgs(
        _ args: [String],
        input: String? = nil,
        workingDirectory: String? = nil
    ) -> ShellOutput {
        guard !args.isEmpty else {
            return ShellOutput(stdout: "", stderr: "No arguments provided", exitCode: -1)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: args[0])
        process.arguments = Array(args.dropFirst())
        process.environment = ProcessInfo.processInfo.environment

        if let workingDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
        }

        let outPipe = Pipe()
        let errPipe = Pipe()
        let inPipe  = Pipe()

        process.standardOutput = outPipe
        process.standardError  = errPipe
        process.standardInput  = inPipe

        do {
            try process.run()

            if let input, let data = input.data(using: .utf8) {
                try inPipe.fileHandleForWriting.write(contentsOf: data)
            }
            try inPipe.fileHandleForWriting.close()

            // Read before waitUntilExit to prevent pipe-buffer deadlock.
            let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()

            process.waitUntilExit()

            let stdout = String(data: outData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let stderr = String(data: errData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            return ShellOutput(stdout: stdout, stderr: stderr, exitCode: process.terminationStatus)
        } catch {
            return ShellOutput(stdout: "", stderr: error.localizedDescription, exitCode: -1)
        }
    }
}
