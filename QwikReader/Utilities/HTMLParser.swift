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
