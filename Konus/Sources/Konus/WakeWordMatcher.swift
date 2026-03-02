import Foundation

struct WakeWordMatch {
    let range: Range<String.Index>
    let matchedWord: String
}

enum WakeWordMatcher {

    /// Find wake word in text using fuzzy matching.
    /// Returns the match range or nil.
    static func find(wakeWord: String, in text: String) -> WakeWordMatch? {
        let textLower = text.lowercased()
        let wakeLower = wakeWord.lowercased()

        // 1. Exact substring match
        if let range = textLower.range(of: wakeLower) {
            let matched = String(textLower[range])
            return WakeWordMatch(range: range, matchedWord: matched)
        }

        // Split into words with ranges
        let words = extractWords(from: textLower)
        let minLen = Int(ceil(Double(wakeLower.count) * 0.55))

        for (word, range) in words {
            guard word.count >= minLen else { continue }

            // 2. Suffix match — word is a suffix of wake word
            //    e.g. "gisayar" is suffix of "bilgisayar"
            if wakeLower.hasSuffix(word) {
                return WakeWordMatch(range: range, matchedWord: word)
            }

            // 3. Levenshtein distance — close to wake word
            let dist = levenshtein(word, wakeLower)
            if dist <= 3 {
                return WakeWordMatch(range: range, matchedWord: word)
            }

            // 4. Near-suffix — suffix of wake word with small edits
            if word.count <= wakeLower.count {
                let suffix = String(wakeLower.suffix(word.count))
                let suffixDist = levenshtein(word, suffix)
                if suffixDist <= 2 {
                    return WakeWordMatch(range: range, matchedWord: word)
                }
            }
        }

        return nil
    }

    // MARK: - Helpers

    private static func extractWords(from text: String) -> [(String, Range<String.Index>)] {
        var results: [(String, Range<String.Index>)] = []

        // Match Turkish + ASCII word characters
        let pattern = "[a-zçğıöşüâîû]+"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return results
        }

        let nsRange = NSRange(text.startIndex..., in: text)
        for match in regex.matches(in: text, range: nsRange) {
            if let range = Range(match.range, in: text) {
                results.append((String(text[range]), range))
            }
        }

        return results
    }

    static func levenshtein(_ a: String, _ b: String) -> Int {
        let m = a.count
        let n = b.count
        let aArr = Array(a)
        let bArr = Array(b)

        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        for i in 0...m { dp[i][0] = i }
        for j in 0...n { dp[0][j] = j }

        for i in 1...m {
            for j in 1...n {
                if aArr[i - 1] == bArr[j - 1] {
                    dp[i][j] = dp[i - 1][j - 1]
                } else {
                    dp[i][j] = 1 + min(dp[i - 1][j], dp[i][j - 1], dp[i - 1][j - 1])
                }
            }
        }
        return dp[m][n]
    }
}
