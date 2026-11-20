import Darwin
import Foundation

@main
enum YapCLI {
    static func main() async {
        do {
            let command = try CLIArguments.parse(Array(CommandLine.arguments.dropFirst()))
            try await run(command)
        } catch let error as CLIArgumentError {
            writeError("yap: \(error.localizedDescription)\nTry 'yap --help' for usage.")
            exit(2)
        } catch {
            writeError("yap: \(error.localizedDescription)")
            exit(1)
        }
    }

    private static func run(_ command: CLICommand) async throws {
        switch command {
        case .transcribe(let path, let options):
            let url = try audioFileURL(for: path)
            let transcript = try await OfflineTranscriber.transcribeFile(
                at: url,
                localeIdentifier: options.localeIdentifier
            )
            try write(transcript, to: options.outputPath)

        case .record(let options, let duration):
            let transcript = try await OfflineTranscriber.record(
                localeIdentifier: options.localeIdentifier,
                onReady: { locale in
                    if let duration {
                        writeError("Recording with \(locale) for \(format(duration)) seconds…")
                    } else {
                        writeError("Recording with \(locale). Press Return to stop.")
                    }
                },
                waitUntilStop: {
                    if let duration {
                        try? await Task.sleep(for: .seconds(duration))
                    } else {
                        _ = await Task.detached { readLine() }.value
                    }
                }
            )
            try write(transcript, to: options.outputPath)

        case .locales:
            let locales = await OfflineTranscriber.installedLocaleIdentifiers()
            if locales.isEmpty {
                throw OfflineTranscriptionError.unavailable
            }
            writeStandardOutput(locales.joined(separator: "\n"))

        case .help:
            writeStandardOutput(help)

        case .version:
            writeStandardOutput("yap \(version)")
        }
    }

    private static func audioFileURL(for path: String) throws -> URL {
        let expanded = NSString(string: path).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded).standardizedFileURL
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
              !isDirectory.boolValue
        else {
            throw CLIFileError.notFound(path)
        }
        return url
    }

    private static func write(_ transcript: String, to outputPath: String?) throws {
        guard let outputPath, outputPath != "-" else {
            writeStandardOutput(transcript)
            return
        }

        let expanded = NSString(string: outputPath).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded).standardizedFileURL
        let contents = transcript + "\n"
        try contents.write(to: url, atomically: true, encoding: .utf8)
    }

    private static func writeStandardOutput(_ text: String) {
        let terminated = text.hasSuffix("\n") ? text : text + "\n"
        FileHandle.standardOutput.write(Data(terminated.utf8))
    }

    private static func writeError(_ text: String) {
        let terminated = text.hasSuffix("\n") ? text : text + "\n"
        FileHandle.standardError.write(Data(terminated.utf8))
    }

    private static func format(_ duration: Double) -> String {
        duration.rounded() == duration
            ? String(Int(duration))
            : String(duration)
    }

    private static var version: String {
        Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "development"
    }

    private static let help = """
    Usage:
      yap [options] <audio-file>
      yap transcribe [options] <audio-file>
      yap record [options]
      yap locales

    Transcribe an audio file:
      yap meeting.m4a
      yap transcribe interview.wav --locale en-US

    Record from the default microphone:
      yap record
      yap record --duration 30 > transcript.txt

    Options:
      -l, --locale <identifier>  BCP-47 locale (defaults to the system locale)
      -o, --output <path>       Write the transcript to a file instead of stdout
          --duration <seconds>  Stop recording after this many seconds
      -h, --help                Show this help
          --version             Show the version

    Yap uses only Apple SpeechTranscriber models already installed on this Mac.
    It never downloads a model and never falls back to cloud transcription.
    Run 'yap locales' to list the available on-device models.
    """
}

private enum CLIFileError: LocalizedError {
    case notFound(String)

    var errorDescription: String? {
        switch self {
        case .notFound(let path):
            return "audio file not found: \(path)"
        }
    }
}
