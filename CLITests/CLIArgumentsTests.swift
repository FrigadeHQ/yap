import Testing

struct CLIArgumentsTests {
    @Test func emptyArgumentsShowHelp() throws {
        #expect(try CLIArguments.parse([]) == .help)
    }

    @Test func barePathTranscribesWithDefaults() throws {
        #expect(
            try CLIArguments.parse(["meeting.m4a"])
                == .transcribe(
                    path: "meeting.m4a",
                    options: CLITranscriptionOptions()
                )
        )
    }

    @Test func explicitTranscribeAcceptsOptionsInAnyOrder() throws {
        #expect(
            try CLIArguments.parse([
                "--locale", "en-US",
                "transcript.wav",
                "--output", "transcript.txt"
            ])
                == .transcribe(
                    path: "transcript.wav",
                    options: CLITranscriptionOptions(
                        localeIdentifier: "en-US",
                        outputPath: "transcript.txt"
                    )
                )
        )
    }

    @Test func recordAcceptsFractionalDuration() throws {
        #expect(
            try CLIArguments.parse([
                "record", "--duration", "1.5", "-l", "en-GB"
            ])
                == .record(
                    options: CLITranscriptionOptions(
                        localeIdentifier: "en-GB",
                        outputPath: nil
                    ),
                    duration: 1.5
                )
        )
    }

    @Test func localesListsModels() throws {
        #expect(try CLIArguments.parse(["locales"]) == .locales)
    }

    @Test func doubleDashAllowsLeadingDashInFileName() throws {
        #expect(
            try CLIArguments.parse(["--", "-recording.wav"])
                == .transcribe(
                    path: "-recording.wav",
                    options: CLITranscriptionOptions()
                )
        )
    }

    @Test func missingOptionValueFails() {
        #expect(throws: CLIArgumentError.missingValue("--locale")) {
            try CLIArguments.parse(["record", "--locale"])
        }
    }

    @Test func invalidDurationFails() {
        #expect(throws: CLIArgumentError.invalidDuration("0")) {
            try CLIArguments.parse(["record", "--duration", "0"])
        }
    }

    @Test func durationIsRejectedForFiles() {
        #expect(throws: CLIArgumentError.durationRequiresRecord) {
            try CLIArguments.parse(["audio.wav", "--duration", "5"])
        }
    }

    @Test func multipleFilesFail() {
        #expect(throws: CLIArgumentError.tooManyAudioFiles) {
            try CLIArguments.parse(["first.wav", "second.wav"])
        }
    }

    @Test func positionalArgumentIsRejectedForRecord() {
        #expect(throws: CLIArgumentError.unexpectedArgument("audio.wav")) {
            try CLIArguments.parse(["record", "audio.wav"])
        }
    }
}
