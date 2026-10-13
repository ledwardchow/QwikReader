import Foundation

enum HTMLParser {
    static func stripHTML(_ html: String) -> String {
        guard !html.isEmpty else { return "" }

        var result = html
        // Remove script/style blocks
        result = result.replacingOccurrences(
            of: "<(script|style)[^>]*>.*?</\\1>",
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        // Replace <br>, <p>, <div> with newlines
        result = result.replacingOccurrences(
            of: "<(br|p|div)[^>]*>",
            with: "\n",
            options: [.regularExpression, .caseInsensitive]
        )
        // Remove all remaining tags
        result = result.replacingOccurrences(
            of: "<[^>]+>",
            with: "",
            options: .regularExpression
        )
        // Decode common entities
        result = result.replacingOccurrences(of: "&amp;", with: "&")
        result = result.replacingOccurrences(of: "&lt;", with: "<")
        result = result.replacingOccurrences(of: "&gt;", with: ">")
        result = result.replacingOccurrences(of: "&quot;", with: "\"")
        result = result.replacingOccurrences(of: "&#39;", with: "'")
        result = result.replacingOccurrences(of: "&apos;", with: "'")
        result = result.replacingOccurrences(of: "&nbsp;", with: " ")
        // Decode numeric entities
        let numericPattern = "&#(\\d+);"
        if let regex = try? NSRegularExpression(pattern: numericPattern) {
            let range = NSRange(result.startIndex..., in: result)
            let matches = regex.matches(in: result, range: range)
            for match in matches.reversed() {
                if let numRange = Range(match.range(at: 1), in: result),
                   let codePoint = UInt32(result[numRange]),
                   let scalar = Unicode.Scalar(codePoint) {
                    let char = String(Character(scalar))
                    if let fullRange = Range(match.range, in: result) {
                        result.replaceSubrange(fullRange, with: char)
                    }
                }
            }
        }
        // Collapse whitespace
        result = result.replacingOccurrences(
            of: "[ \\t]+",
            with: " ",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: "\\n{3,}",
            with: "\n\n",
            options: .regularExpression
        )
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Strips the leading <h1> and any <figure> or <img> whose src contains the given URL string.
    static func stripReaderViewDuplicates(from html: String, heroImageURL: URL?) -> String {
        var result = html

        // Remove leading <h1>
        let h1Pattern = "^\\s*<h1[^>]*>.*?</h1>\\s*"
        if let regex = try? NSRegularExpression(pattern: h1Pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
            result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "")
        }

        // Remove figure or img whose src matches the hero image URL
        if let imageURL = heroImageURL?.absoluteString {
            // Escape for use inside a regex pattern
            let escaped = NSRegularExpression.escapedPattern(for: imageURL)
            // Match <figure>...</figure> containing this src
            let figurePattern = "<figure[^>]*>(?:(?!</figure>)[\\s\\S])*\(escaped)(?:(?!</figure>)[\\s\\S])*</figure>"
            if let regex = try? NSRegularExpression(pattern: figurePattern, options: .caseInsensitive) {
                result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "")
            }
            // Match standalone <img src="...matchingURL...">
            let imgPattern = "<img[^>]*src=[\"'][^\"']*\(escaped)[^\"']*[\"'][^>]*/?>\\s*"
            if let regex = try? NSRegularExpression(pattern: imgPattern, options: .caseInsensitive) {
                result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "")
            }
        }

        return result
    }

    static func extractFirstImageURL(from html: String) -> String? {
        let pattern = "<img[^>]+src=[\"']([^\"']+)[\"']"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let range = NSRange(html.startIndex..., in: html)
        if let match = regex.firstMatch(in: html, range: range),
           let urlRange = Range(match.range(at: 1), in: html) {
            return String(html[urlRange])
        }
        return nil
    }
}
