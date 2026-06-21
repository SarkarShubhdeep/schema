//
//  AtMentionParser.swift
//  Schema
//

import Foundation

struct ParsedAtMentions {
    var cleanTitle: String
    var detectedTime: Date?
    var detectedDate: Date?
    var detectedList: SchemaList?
    var listCandidates: [SchemaList]
    var activeListPrefix: String?

    var hasResolvedMentions: Bool {
        detectedTime != nil || detectedDate != nil || detectedList != nil
    }

    var hasPreviewContent: Bool {
        hasResolvedMentions || !listCandidates.isEmpty
    }

    func resolvedList(at index: Int) -> SchemaList? {
        if listCandidates.isEmpty {
            return detectedList
        }
        let clampedIndex = min(max(index, 0), listCandidates.count - 1)
        return listCandidates[clampedIndex]
    }

    /// Merges parsed date and time into a single reminder datetime.
    func mergedReminderDate(calendar: Calendar = .current) -> Date? {
        if detectedTime == nil, detectedDate == nil {
            return nil
        }

        if let time = detectedTime, detectedDate == nil {
            let components = calendar.dateComponents([.hour, .minute], from: time)
            return Self.nextOccurrence(
                hour: components.hour ?? 0,
                minute: components.minute ?? 0,
                calendar: calendar
            )
        }

        guard let dateDay = detectedDate else {
            return detectedTime
        }

        if let time = detectedTime {
            let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
            var dateComponents = calendar.dateComponents([.year, .month, .day], from: dateDay)
            dateComponents.hour = timeComponents.hour
            dateComponents.minute = timeComponents.minute
            dateComponents.second = 0
            return calendar.date(from: dateComponents)
        }

        return nil
    }

    private static func nextOccurrence(hour: Int, minute: Int, calendar: Calendar = .current) -> Date {
        let now = Date()

        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = hour
        components.minute = minute
        components.second = 0

        guard let todayAtTime = calendar.date(from: components) else {
            return now
        }

        if todayAtTime > now {
            return todayAtTime
        } else {
            return calendar.date(byAdding: .day, value: 1, to: todayAtTime) ?? todayAtTime
        }
    }
}

enum AtMentionParser {
    static let minimumListPrefixLength = 3

    /// Live hints while typing — does not strip tokens from the title.
    static func preview(_ text: String, lists: [SchemaList]) -> ParsedAtMentions {
        parse(text, lists: lists, mode: .preview)
    }

    /// Applies mentions — strips recognized tokens and resolves the best list match.
    static func commit(_ text: String, lists: [SchemaList]) -> ParsedAtMentions {
        parse(text, lists: lists, mode: .commit)
    }

    private enum ParseMode {
        case preview
        case commit
    }

    private struct TokenMatch {
        let tokenLength: Int
        let time: Date?
        let date: Date?
        let list: SchemaList?
        let listPrefix: String?
        let listCandidates: [SchemaList]
    }

    private static func parse(_ text: String, lists: [SchemaList], mode: ParseMode) -> ParsedAtMentions {
        var cleanTitle = text
        var detectedTime: Date?
        var detectedDate: Date?
        var detectedList: SchemaList?
        var listCandidates: [SchemaList] = []
        var activeListPrefix: String?

        let writableLists = sortedWritableLists(lists)
        var searchStart = cleanTitle.startIndex

        while searchStart < cleanTitle.endIndex {
            guard let atIndex = cleanTitle[searchStart...].firstIndex(of: "@") else { break }

            let afterAt = cleanTitle.index(after: atIndex)
            guard afterAt < cleanTitle.endIndex else { break }

            let remainder = String(cleanTitle[afterAt...])
            let match = matchToken(in: remainder, lists: writableLists, mode: mode)

            if let match {
                if let date = match.date {
                    detectedDate = date
                }
                if let time = match.time {
                    detectedTime = time
                }
                if let list = match.list {
                    detectedList = list
                }
                if let prefix = match.listPrefix {
                    activeListPrefix = prefix
                }
                if !match.listCandidates.isEmpty {
                    listCandidates = match.listCandidates
                }

                if mode == .commit, match.tokenLength > 0 {
                    let tokenEnd = cleanTitle.index(atIndex, offsetBy: 1 + match.tokenLength)
                    cleanTitle.removeSubrange(atIndex..<tokenEnd)
                    searchStart = atIndex
                    continue
                }
            }

            searchStart = cleanTitle.index(after: atIndex)
        }

        if mode == .preview {
            cleanTitle = text
        } else {
            cleanTitle = collapseWhitespace(cleanTitle)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return ParsedAtMentions(
            cleanTitle: cleanTitle,
            detectedTime: detectedTime,
            detectedDate: detectedDate,
            detectedList: detectedList,
            listCandidates: listCandidates,
            activeListPrefix: activeListPrefix
        )
    }

    private static func matchToken(
        in remainder: String,
        lists: [SchemaList],
        mode: ParseMode
    ) -> TokenMatch? {
        if let dateMatch = matchDateKeyword(in: remainder) {
            return TokenMatch(
                tokenLength: dateMatch.tokenLength,
                time: nil,
                date: dateMatch.date,
                list: nil,
                listPrefix: nil,
                listCandidates: []
            )
        }

        if let dateMatch = matchFormattedDate(in: remainder) {
            return TokenMatch(
                tokenLength: dateMatch.tokenLength,
                time: nil,
                date: dateMatch.date,
                list: nil,
                listPrefix: nil,
                listCandidates: []
            )
        }

        if let timeMatch = matchTimeToken(in: remainder) {
            return TokenMatch(
                tokenLength: timeMatch.tokenLength,
                time: timeMatch.date,
                date: nil,
                list: nil,
                listPrefix: nil,
                listCandidates: []
            )
        }

        if let listMatch = matchListToken(in: remainder, lists: lists, mode: mode) {
            return TokenMatch(
                tokenLength: listMatch.tokenLength,
                time: nil,
                date: nil,
                list: listMatch.list,
                listPrefix: listMatch.prefix,
                listCandidates: listMatch.candidates
            )
        }

        return nil
    }

    private static func sortedWritableLists(_ lists: [SchemaList]) -> [SchemaList] {
        lists
            .filter { !$0.isEverythingList }
            .sorted {
                $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
    }

    private struct DateTokenMatch {
        let date: Date
        let tokenLength: Int
    }

    private struct TimeTokenMatch {
        let date: Date
        let tokenLength: Int
    }

    private struct ListTokenMatch {
        let list: SchemaList?
        let prefix: String?
        let candidates: [SchemaList]
        let tokenLength: Int
    }

    private static func matchDateKeyword(in remainder: String) -> DateTokenMatch? {
        let keywords: [(word: String, dayOffset: Int)] = [
            ("tomorrow", 1),
            ("today", 0),
        ]

        for keyword in keywords {
            guard remainder.lowercased().hasPrefix(keyword.word) else { continue }

            let endIndex = remainder.index(
                remainder.startIndex,
                offsetBy: keyword.word.count,
                limitedBy: remainder.endIndex
            )
            guard let endIndex else { continue }

            if endIndex == remainder.endIndex || remainder[endIndex].isWhitespace {
                let calendar = Calendar.current
                let startOfToday = calendar.startOfDay(for: Date())
                let date = calendar.date(byAdding: .day, value: keyword.dayOffset, to: startOfToday) ?? startOfToday
                return DateTokenMatch(date: date, tokenLength: keyword.word.count)
            }
        }

        return nil
    }

    private static func matchFormattedDate(in remainder: String) -> DateTokenMatch? {
        let patterns = [
            #"^(\d{1,2})/(\d{1,2})/(\d{2,4})"#,
            #"^(\d{1,2})/(\d{1,2})"#,
            #"^([A-Za-z]{3,9})\s+(\d{1,2})(?:,\s*(\d{4}))?"#,
            #"^([A-Za-z]{3,9})(\d{1,2})"#,
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                continue
            }

            let nsRange = NSRange(remainder.startIndex..<remainder.endIndex, in: remainder)
            guard let match = regex.firstMatch(in: remainder, range: nsRange) else { continue }

            guard let tokenRange = Range(match.range, in: remainder) else { continue }
            let token = String(remainder[tokenRange])

            let endIndex = tokenRange.upperBound
            if endIndex < remainder.endIndex, !remainder[endIndex].isWhitespace {
                continue
            }

            if let date = parseDateToken(token) {
                return DateTokenMatch(date: date, tokenLength: token.count)
            }
        }

        return nil
    }

    private static func parseDateToken(_ token: String) -> Date? {
        let formatters = [
            "M/d/yyyy", "M/d/yy", "M/d",
            "MMM d, yyyy", "MMM d", "MMMM d, yyyy", "MMMM d",
            "MMMd", "MMMMd",
        ]

        for format in formatters {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = format
            if let date = formatter.date(from: token) {
                return Calendar.current.startOfDay(for: date)
            }
        }

        return nil
    }

    private static func matchTimeToken(in remainder: String) -> TimeTokenMatch? {
        if let twelveHourRange = remainder.range(
            of: #"^(\d{1,2})(?::(\d{2}))?\s*(am|pm)"#,
            options: [.regularExpression, .caseInsensitive]
        ) {
            let token = String(remainder[twelveHourRange])
            if let date = parseTwelveHourToken(token) {
                return TimeTokenMatch(date: date, tokenLength: token.count)
            }
        }

        if let twentyFourHourRange = remainder.range(
            of: #"^(\d{1,2}):(\d{2})(?!\d)"#,
            options: .regularExpression
        ) {
            let token = String(remainder[twentyFourHourRange])
            if let date = parseTwentyFourHourToken(token) {
                return TimeTokenMatch(date: date, tokenLength: token.count)
            }
        }

        return nil
    }

    private static func matchListToken(
        in remainder: String,
        lists: [SchemaList],
        mode: ParseMode
    ) -> ListTokenMatch? {
        guard let extraction = extractListMention(from: remainder, lists: lists) else { return nil }

        let prefix = extraction.prefix
        let candidates = extraction.candidates

        switch mode {
        case .preview:
            return ListTokenMatch(
                list: candidates.count == 1 ? candidates[0] : nil,
                prefix: prefix,
                candidates: candidates,
                tokenLength: 0
            )
        case .commit:
            return ListTokenMatch(
                list: candidates.first,
                prefix: prefix,
                candidates: candidates,
                tokenLength: prefix.count
            )
        }
    }

    private struct ListMentionExtraction {
        let prefix: String
        let candidates: [SchemaList]
    }

    private static func extractListMention(from remainder: String, lists: [SchemaList]) -> ListMentionExtraction? {
        guard !remainder.isEmpty else { return nil }

        let remainderLower = remainder.lowercased()

        for keyword in ["tomorrow", "today"] {
            guard remainderLower.hasPrefix(keyword) else { continue }
            let endIndex = remainder.index(remainder.startIndex, offsetBy: keyword.count, limitedBy: remainder.endIndex)
            guard let endIndex else { continue }
            if endIndex == remainder.endIndex || remainder[endIndex].isWhitespace {
                return nil
            }
        }

        if remainder.first?.isNumber == true {
            return nil
        }

        if let exactMatch = exactListTitleMatch(in: remainder, lists: lists) {
            return exactMatch
        }

        let words = remainder.split(separator: " ", omittingEmptySubsequences: true)
        guard !words.isEmpty else { return nil }

        var accumulated = ""
        var lastPrefix = ""
        var lastCandidates: [SchemaList] = []

        for word in words {
            accumulated = accumulated.isEmpty ? String(word) : accumulated + " " + word

            if accumulated.count < minimumListPrefixLength {
                continue
            }

            let candidates = matchingLists(prefix: accumulated, in: lists)
            if candidates.isEmpty {
                break
            }

            lastPrefix = accumulated
            lastCandidates = candidates

            if candidates.count == 1, isExactListNameMatch(accumulated, list: candidates[0]) {
                break
            }
        }

        if lastCandidates.isEmpty {
            let firstWord = String(words[0])
            guard firstWord.count >= minimumListPrefixLength else { return nil }
            lastCandidates = matchingLists(prefix: firstWord, in: lists)
            guard !lastCandidates.isEmpty else { return nil }
            lastPrefix = firstWord
        }

        let prefixEnd = remainder.index(remainder.startIndex, offsetBy: lastPrefix.count, limitedBy: remainder.endIndex)
        guard let prefixEnd else { return nil }
        let displayPrefix = String(remainder[..<prefixEnd])

        return ListMentionExtraction(prefix: displayPrefix, candidates: lastCandidates)
    }

    private static func exactListTitleMatch(in remainder: String, lists: [SchemaList]) -> ListMentionExtraction? {
        let sortedLists = lists.sorted { $0.title.count > $1.title.count }

        for list in sortedLists {
            for name in [list.title, list.displayTagLabel] where !name.isEmpty {
                guard remainder.lowercased().hasPrefix(name.lowercased()) else { continue }

                let endIndex = remainder.index(remainder.startIndex, offsetBy: name.count, limitedBy: remainder.endIndex)
                guard let endIndex else { continue }
                if endIndex == remainder.endIndex || remainder[endIndex].isWhitespace {
                    let prefix = String(remainder[..<endIndex])
                    return ListMentionExtraction(prefix: prefix, candidates: [list])
                }
            }
        }

        return nil
    }

    private static func matchingLists(prefix: String, in lists: [SchemaList]) -> [SchemaList] {
        let prefixLower = prefix.lowercased()
        return lists.filter { list in
            list.title.lowercased().hasPrefix(prefixLower)
                || list.displayTagLabel.lowercased().hasPrefix(prefixLower)
        }
        .sorted {
            $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
    }

    private static func isExactListNameMatch(_ prefix: String, list: SchemaList) -> Bool {
        let prefixLower = prefix.lowercased()
        return list.title.lowercased() == prefixLower
            || list.displayTagLabel.lowercased() == prefixLower
    }

    private static func parseTwelveHourToken(_ token: String) -> Date? {
        guard let regex = try? NSRegularExpression(
            pattern: #"^(\d{1,2})(?::(\d{2}))?\s*(am|pm)$"#,
            options: [.caseInsensitive]
        ) else { return nil }

        let nsRange = NSRange(token.startIndex..<token.endIndex, in: token)
        guard let match = regex.firstMatch(in: token, range: nsRange) else { return nil }

        guard
            let hourRange = Range(match.range(at: 1), in: token),
            let meridiemRange = Range(match.range(at: 3), in: token),
            let hourValue = Int(token[hourRange])
        else { return nil }

        let minuteValue: Int
        if match.range(at: 2).location != NSNotFound,
           let minuteRange = Range(match.range(at: 2), in: token),
           let parsedMinute = Int(token[minuteRange]) {
            minuteValue = parsedMinute
        } else {
            minuteValue = 0
        }

        guard hourValue >= 1, hourValue <= 12, minuteValue >= 0, minuteValue <= 59 else { return nil }

        let meridiem = token[meridiemRange].lowercased()
        let hour24: Int
        if meridiem == "am" {
            hour24 = hourValue == 12 ? 0 : hourValue
        } else {
            hour24 = hourValue == 12 ? 12 : hourValue + 12
        }

        return timeReference(hour: hour24, minute: minuteValue)
    }

    private static func parseTwentyFourHourToken(_ token: String) -> Date? {
        guard let regex = try? NSRegularExpression(pattern: #"^(\d{1,2}):(\d{2})$"#) else { return nil }

        let nsRange = NSRange(token.startIndex..<token.endIndex, in: token)
        guard let match = regex.firstMatch(in: token, range: nsRange) else { return nil }

        guard
            let hourRange = Range(match.range(at: 1), in: token),
            let minuteRange = Range(match.range(at: 2), in: token),
            let hourValue = Int(token[hourRange]),
            let minuteValue = Int(token[minuteRange])
        else { return nil }

        guard hourValue >= 0, hourValue <= 23, minuteValue >= 0, minuteValue <= 59 else { return nil }

        return timeReference(hour: hourValue, minute: minuteValue)
    }

    /// Returns a Date whose hour/minute components represent the parsed time.
    private static func timeReference(hour: Int, minute: Int) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute
        components.second = 0
        return calendar.date(from: components) ?? Date()
    }

    private static func collapseWhitespace(_ text: String) -> String {
        text
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }
}
