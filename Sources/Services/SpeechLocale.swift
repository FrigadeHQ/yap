import Foundation

/// Maps the user's locale onto one a speech engine actually supports.
///
/// `Locale.current` cannot be handed to a speech API verbatim. When the system
/// language and region disagree — English (US) with the region set to Spain,
/// say — macOS represents that as `en_US@rg=eszzzz`, which serializes to BCP-47
/// as `en-US-u-rg-eszzzz`. No engine lists that string among its supported
/// locales, so comparing identifiers exactly concludes the language is
/// unsupported even though `en-US` is right there with its model installed.
///
/// Matching therefore widens in three steps: the exact tag, then the same
/// language and region ignoring extensions, then the same language in any
/// region.
enum SpeechLocale {
    static func bestMatch<Candidates: Sequence>(
        for locale: Locale,
        in candidates: Candidates
    ) -> Locale? where Candidates.Element == Locale {
        // `supportedLocales` is unordered, so sort to keep the widened matches
        // stable from one launch to the next.
        let ordered = candidates.sorted { $0.identifier(.bcp47) < $1.identifier(.bcp47) }

        if let exact = ordered.first(where: { $0.identifier(.bcp47) == locale.identifier(.bcp47) }) {
            return exact
        }

        guard let language = locale.language.languageCode?.identifier else { return nil }

        // `locale.language.region`, not `locale.region`: the latter reports the
        // regional override (ES in the example above) rather than the region of
        // the language being spoken (US).
        if let region = locale.language.region?.identifier,
           let regional = ordered.first(where: {
               $0.language.languageCode?.identifier == language
                   && $0.language.region?.identifier == region
           }) {
            return regional
        }

        return ordered.first { $0.language.languageCode?.identifier == language }
    }
}
