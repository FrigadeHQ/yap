import Foundation

struct CLITranscriptionOptions: Equatable {
    var localeIdentifier: String?
    var outputPath: String?
}

enum CLICommand: Equatable {
    case transcribe(path: String, options: CLITranscriptionOptions)
    case record(options: CLITranscriptionOptions, duration: Double?)
    case locales
    case help
    case version
}

enum CLIArgumentError: LocalizedError, Equatable {
    case missingValue(String)
    case invalidDuration(String)
    case unsupportedOption(String)
    case unexpectedArgument(String)
    case missingAudioFile
    case tooManyAudioFiles
    case durationRequiresRecord

    var errorDescription: String? {
        switch self {
        case .missingValue(let option):
            return "\(option) requires a value"
        case .invalidDuration(let value):
            return "invalid duration '\(value)'; expected a number greater than zero"
        case .unsupportedOption(let option):
            return "unknown option '\(option)'"
        case .unexpectedArgument(let argument):
            return "unexpected argument '\(argument)'"
        case .missingAudioFile:
            return "missing audio file"
        case .tooManyAudioFiles:
            return "expected exactly one audio file"
        case .durationRequiresRecord:
            return "--duration is only valid with 'record'"
        }
    }
}

enum CLIArguments {
    static func parse(_ arguments: [String]) throws -> CLICommand {
        guard !arguments.isEmpty else { return .help }

        var remaining = arguments
        let mode: Mode

        switch remaining.first {
        case "transcribe":
            mode = .transcribe
            remaining.removeFirst()
        case "record":
            mode = .record
            remaining.removeFirst()
        case "locales":
            guard remaining.count == 1 else {
                throw CLIArgumentError.unexpectedArgument(remaining[1])
            }
            return .locales
        case "help", "--help", "-h":
            return .help
        case "version", "--version":
            return .version
        default:
            mode = .transcribe
        }

        var options = CLITranscriptionOptions()
        var duration: Double?
        var positionals: [String] = []
        var index = 0

        while index < remaining.count {
            let argument = remaining[index]

            switch argument {
            case "--help", "-h":
                return .help
            case "--version":
                return .version
            case "--locale", "-l":
                options.localeIdentifier = try value(after: argument, in: remaining, index: &index)
            case "--output", "-o":
                options.outputPath = try value(after: argument, in: remaining, index: &index)
            case "--duration":
                let rawValue = try value(after: argument, in: remaining, index: &index)
                guard let parsed = Double(rawValue), parsed.isFinite, parsed > 0 else {
                    throw CLIArgumentError.invalidDuration(rawValue)
                }
                duration = parsed
            case "--":
                positionals.append(contentsOf: remaining.dropFirst(index + 1))
                index = remaining.count
                continue
            default:
                if argument.hasPrefix("-") {
                    throw CLIArgumentError.unsupportedOption(argument)
                }
                positionals.append(argument)
            }

            index += 1
        }

        switch mode {
        case .transcribe:
            guard duration == nil else {
                throw CLIArgumentError.durationRequiresRecord
            }
            guard !positionals.isEmpty else {
                throw CLIArgumentError.missingAudioFile
            }
            guard positionals.count == 1 else {
                throw CLIArgumentError.tooManyAudioFiles
            }
            return .transcribe(path: positionals[0], options: options)
        case .record:
            guard positionals.isEmpty else {
                throw CLIArgumentError.unexpectedArgument(positionals[0])
            }
            return .record(options: options, duration: duration)
        }
    }

    private enum Mode {
        case transcribe
        case record
    }

    private static func value(
        after option: String,
        in arguments: [String],
        index: inout Int
    ) throws -> String {
        let valueIndex = index + 1
        guard valueIndex < arguments.count else {
            throw CLIArgumentError.missingValue(option)
        }
        index = valueIndex
        return arguments[valueIndex]
    }
}
