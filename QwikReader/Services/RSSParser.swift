import Foundation

final class RSSParser: NSObject, XMLParserDelegate {
    private var feedTitle = ""
    private var feedDescription = ""
    private var feedLink = ""
    private var articles: [ParsedArticle] = []

    private var currentElement = ""
    private var currentText = ""
    private var currentItem: ParsedArticle?
    private var isInsideItem = false
    private var isAtom = false
    private var cdataBuffer = Data()

    struct ParsedArticle {
        var title = ""
        var link = ""
        var author = ""
        var summary = ""
        var content = ""
        var imageURL = ""
        var pubDate = ""
    }

    struct ParsedFeed {
        var title: String
        var description: String
        var siteURL: String
        var articles: [ParsedArticle]
    }

    func parse(data: Data) -> ParsedFeed? {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.shouldResolveExternalEntities = false

        guard parser.parse() else { return nil }

        return ParsedFeed(
            title: feedTitle.trimmingCharacters(in: .whitespacesAndNewlines),
            description: feedDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            siteURL: feedLink.trimmingCharacters(in: .whitespacesAndNewlines),
            articles: articles
        )
    }

    // MARK: - XMLParserDelegate

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName: String?, attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName
        currentText = ""
        cdataBuffer = Data()

        if elementName == "feed" { isAtom = true }

        if elementName == "item" || elementName == "entry" {
            isInsideItem = true
            currentItem = ParsedArticle()
        }

        if isAtom && elementName == "link" {
            let rel = attributeDict["rel"] ?? "alternate"
            if let href = attributeDict["href"] {
                if isInsideItem && rel == "alternate" {
                    currentItem?.link = href
                } else if !isInsideItem && (rel == "alternate" || rel == "") {
                    feedLink = href
                }
            }
        }

        if elementName == "media:content" || elementName == "media:thumbnail" {
            if let url = attributeDict["url"], isInsideItem {
                currentItem?.imageURL = url
            }
        }

        if elementName == "enclosure", let url = attributeDict["url"],
           let type = attributeDict["type"], type.starts(with: "image/"), isInsideItem {
            currentItem?.imageURL = url
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        cdataBuffer.append(CDATABlock)
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
        let text: String
        if !cdataBuffer.isEmpty {
            text = String(data: cdataBuffer, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        } else {
            text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if isInsideItem {
            switch elementName {
            case "title": currentItem?.title = text
            case "link" where !isAtom: currentItem?.link = text
            case "author", "dc:creator": currentItem?.author = text
            case "description", "summary": currentItem?.summary = text
            case "content:encoded", "content": currentItem?.content = text
            case "pubDate", "published", "updated", "dc:date":
                currentItem?.pubDate = text
            default: break
            }

            if currentItem?.imageURL.isEmpty == true {
                let imgURL = HTMLParser.extractFirstImageURL(from: text)
                if let imgURL { currentItem?.imageURL = imgURL }
            }
        } else {
            switch elementName {
            case "title": feedTitle = text
            case "description", "subtitle": feedDescription = text
            case "link" where !isAtom: feedLink = text
            default: break
            }
        }

        if elementName == "item" || elementName == "entry" {
            if let item = currentItem {
                articles.append(item)
            }
            isInsideItem = false
            currentItem = nil
        }
    }

    // MARK: - Date Parsing

    static func parseDate(_ string: String) -> Date? {
        let formatters: [DateFormatter] = {
            let rfc822 = DateFormatter()
            rfc822.locale = Locale(identifier: "en_US_POSIX")
            rfc822.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"

            let rfc822Alt = DateFormatter()
            rfc822Alt.locale = Locale(identifier: "en_US_POSIX")
            rfc822Alt.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"

            let iso8601 = DateFormatter()
            iso8601.locale = Locale(identifier: "en_US_POSIX")
            iso8601.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"

            let iso8601ms = DateFormatter()
            iso8601ms.locale = Locale(identifier: "en_US_POSIX")
            iso8601ms.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"

            return [rfc822, rfc822Alt, iso8601, iso8601ms]
        }()

        for formatter in formatters {
            if let date = formatter.date(from: string) {
                return date
            }
        }
        return nil
    }
}
