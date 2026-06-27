 import Foundation
 import NaturalLanguage
 
 /// Analyzes sentiment and extracts keywords from transcribed journal entries.
 /// Creates fresh taggers per call — safe for concurrent use.
 struct SentimentAnalyzer {
     
     private static let stopWords: Set<String> = [
         "the", "a", "an", "and", "or", "but", "in", "on", "at", "to", "for",
         "of", "with", "by", "is", "was", "are", "were", "be", "been", "being",
         "have", "has", "had", "do", "does", "did", "will", "would", "could",
         "should", "may", "might", "shall", "can", "it", "its", "that", "this",
         "these", "those", "i", "me", "my", "we", "our", "you", "your", "he",
         "she", "they", "them", "not", "no", "yes", "so", "if", "then", "than",
         "too", "very", "just", "also", "about", "up", "out", "as", "into",
         "over", "after", "before", "between", "under", "again", "further",
         "once", "here", "there", "when", "where", "why", "how", "all", "each",
         "every", "both", "few", "more", "most", "other", "some", "such", "only",
         "own", "same", "so", "than", "too", "very", "just", "because", "but",
         "which", "who", "whom", "what"
     ]
     
     /// Returns sentiment score from -1.0 (negative) to 1.0 (positive)
     func analyzeSentiment(_ text: String) -> Double {
         let tagger = NLTagger(tagSchemes: [.sentimentScore])
         tagger.string = text
         let (sentiment, _) = tagger.tag(at: text.startIndex, unit: .paragraph, scheme: .sentimentScore)
         if let sentiment = sentiment {
             return Double(sentiment.rawValue) ?? 0.0
         }
         return 0.0
     }
     
     /// Extracts key topics and named entities from the text
     func extractKeywords(_ text: String) -> [String] {
         var keywords: Set<String> = []
         
         // Extract named entities (persons, places, organizations)
         let nameTagger = NLTagger(tagSchemes: [.nameType])
         nameTagger.string = text
         nameTagger.enumerateTags(in: text.startIndex..<text.endIndex,
             unit: .word, scheme: .nameType) { tag, range in
             if tag != nil {
                 keywords.insert(String(text[range]).lowercased())
             }
             return true
         }
         
         // Also extract frequent important words using tokenization
         let tokenizer = NLTokenizer(unit: .word)
         tokenizer.string = text
         var wordFreq: [String: Int] = [:]
         
         tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
             let word = String(text[range]).lowercased().trimmingCharacters(in: .punctuationCharacters)
             if word.count > 2 && !Self.stopWords.contains(word) {
                 wordFreq[word, default: 0] += 1
             }
             return true
         }
         
         // Return top frequency words + named entities
         let frequentWords = wordFreq.filter { $0.value >= 2 }.map(\.key)
         return Array(keywords.union(frequentWords)).sorted()
     }
     
     /// Generates a one-sentence insight string
     func generateInsight(from text: String) -> String {
         let sentiment = analyzeSentiment(text)
         let keywords = extractKeywords(text)
         let wordCount = text.split(separator: " ").count
         
         var parts: [String] = []
         
         if sentiment > 0.4 { parts.append("Positive tone") }
         else if sentiment > 0.1 { parts.append("Slightly positive tone") }
         else if sentiment > -0.1 { parts.append("Neutral tone") }
         else if sentiment > -0.4 { parts.append("Slightly negative tone") }
         else { parts.append("Negative tone") }
         
         parts.append("\(wordCount) words")
         
         if !keywords.isEmpty {
             let top = keywords.prefix(3).joined(separator: ", ")
             parts.append("Mentions: \(top)")
         }
         
         return parts.joined(separator: " • ")
     }
 }
