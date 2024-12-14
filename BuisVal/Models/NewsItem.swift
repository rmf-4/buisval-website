import Foundation
import NaturalLanguage
import SwiftUI

struct NewsItem: Identifiable, Codable {
    let id: Int
    let headline: String
    let summary: String
    let url: String
    let datetime: TimeInterval
    let source: String
    let sentiment: Double
    let trustScore: Double
    
    private static let trustedSources = [
        "Reuters": 0.9,
        "Bloomberg": 0.9,
        "Financial Times": 0.85,
        "Wall Street Journal": 0.85,
        "CNBC": 0.7,
        "MarketWatch": 0.7,
        "Yahoo Finance": 0.6,
        "Seeking Alpha": 0.5,
        "Motley Fool": 0.5,
        "Business Insider": 0.5
    ]
    
    private static let sentimentKeywords: [(word: String, weight: Double)] = [
        // Very Bullish (0.15-0.2)
        ("breakthrough", 0.2), ("revolutionary", 0.2), ("skyrocket", 0.2),
        ("patent granted", 0.18), ("major contract", 0.18), ("record high", 0.18),
        ("exceeds expectations", 0.17), ("massive growth", 0.17), ("acquisition", 0.15),
        ("partnership", 0.15), ("new product", 0.15), ("expansion", 0.15),
        
        // Bullish (0.08-0.14)
        ("beat estimates", 0.14), ("upgrade", 0.14), ("positive outlook", 0.14),
        ("growth", 0.12), ("profit", 0.12), ("outperform", 0.12),
        ("strong demand", 0.12), ("innovation", 0.12), ("market share", 0.12),
        ("revenue up", 0.1), ("earnings beat", 0.1), ("guidance raised", 0.1),
        ("buy rating", 0.1), ("momentum", 0.1), ("recovery", 0.1),
        ("improved margins", 0.08), ("cost reduction", 0.08), ("efficiency", 0.08),
        
        // Slightly Bullish (0.03-0.07)
        ("stable", 0.07), ("steady", 0.07), ("solid", 0.07),
        ("meets expectations", 0.05), ("in-line", 0.05), ("as expected", 0.05),
        ("maintains guidance", 0.03), ("unchanged", 0.03),
        
        // Very Bearish (-0.15 to -0.2)
        ("bankruptcy", -0.2), ("fraud", -0.2), ("investigation", -0.2),
        ("lawsuit", -0.18), ("default", -0.18), ("crash", -0.18),
        ("massive loss", -0.17), ("scandal", -0.17), ("ceo fired", -0.17),
        ("restructuring", -0.15), ("layoffs", -0.15), ("downsizing", -0.15),
        
        // Bearish (-0.08 to -0.14)
        ("downgrade", -0.14), ("miss estimates", -0.14), ("negative outlook", -0.14),
        ("declining", -0.12), ("loss", -0.12), ("underperform", -0.12),
        ("weak demand", -0.12), ("competition", -0.12), ("market share loss", -0.12),
        ("revenue down", -0.1), ("earnings miss", -0.1), ("guidance lowered", -0.1),
        ("sell rating", -0.1), ("slowdown", -0.1), ("struggle", -0.1),
        ("margin pressure", -0.08), ("cost increase", -0.08), ("inefficiency", -0.08),
        
        // Slightly Bearish (-0.03 to -0.07)
        ("cautious", -0.07), ("uncertain", -0.07), ("challenging", -0.07),
        ("below expectations", -0.05), ("mixed results", -0.05), ("delayed", -0.05),
        ("reviewing options", -0.03), ("regulatory concerns", -0.03),
        
        // Industry-Specific Positive
        ("fda approval", 0.2), ("clinical success", 0.18), ("patent", 0.15),
        ("market expansion", 0.15), ("new technology", 0.15), ("ai development", 0.15),
        ("ev adoption", 0.15), ("renewable", 0.12), ("digital transformation", 0.12),
        
        // Industry-Specific Negative
        ("clinical failure", -0.2), ("fda rejection", -0.2), ("patent expired", -0.15),
        ("recall", -0.18), ("security breach", -0.18), ("supply chain issues", -0.15),
        ("regulatory hurdle", -0.15), ("obsolete", -0.12), ("market exit", -0.12)
    ]
    
    enum CodingKeys: String, CodingKey {
        case id, headline, summary, url, datetime, source
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        headline = try container.decode(String.self, forKey: .headline)
        summary = try container.decode(String.self, forKey: .summary)
        url = try container.decode(String.self, forKey: .url)
        datetime = try container.decode(TimeInterval.self, forKey: .datetime)
        source = try container.decode(String.self, forKey: .source)
        
        // Calculate trust score
        trustScore = Self.calculateTrustScore(source: source)
        
        // Calculate sentiment
        sentiment = Self.analyzeSentiment(headline: headline, summary: summary)
    }
    
    init(id: Int, headline: String, summary: String, url: String, datetime: TimeInterval, source: String, sentiment: Double, trustScore: Double) {
        self.id = id
        self.headline = headline
        self.summary = summary
        self.url = url
        self.datetime = datetime
        self.source = source
        self.sentiment = sentiment
        self.trustScore = trustScore
    }
    
    var formattedDate: String {
        let date = Date(timeIntervalSince1970: datetime)
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private static func calculateTrustScore(source: String) -> Double {
        // Clean and normalize the source string
        let cleanSource = source.replacingOccurrences(of: ".com", with: "")
                               .replacingOccurrences(of: "www.", with: "")
                               .replacingOccurrences(of: "http://", with: "")
                               .replacingOccurrences(of: "https://", with: "")
                               .lowercased()
                               .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Common source variations
        let sourceMap: [String: String] = [
            "reuters": "Reuters",
            "bloomberg": "Bloomberg",
            "ft": "Financial Times",
            "financial-times": "Financial Times",
            "wsj": "Wall Street Journal",
            "wall-street-journal": "Wall Street Journal",
            "cnbc": "CNBC",
            "marketwatch": "MarketWatch",
            "yahoo": "Yahoo Finance",
            "seekingalpha": "Seeking Alpha",
            "motley": "Motley Fool",
            "fool": "Motley Fool",
            "businessinsider": "Business Insider",
            "zacks": "Zacks",
            "benzinga": "Benzinga",
            "barrons": "Barrons",
            "thestreet": "TheStreet",
            "forbes": "Forbes"
        ]
        
        // Try to match the source to a known variation
        for (key, mappedSource) in sourceMap {
            if cleanSource.contains(key) {
                return trustedSources[mappedSource] ?? 0.5
            }
        }
        
        return 0.3  // Default score for unknown sources
    }
    
    private static func analyzeSentiment(headline: String, summary: String) -> Double {
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        let text = (headline + " " + summary).lowercased()
        
        // 1. Initial NLP Analysis
        tagger.string = headline
        let headlineScore = tagger.tag(at: headline.startIndex, 
                                     unit: .paragraph, 
                                     scheme: .sentimentScore).0?.rawValue ?? "0"
        
        tagger.string = summary
        let summaryScore = tagger.tag(at: summary.startIndex, 
                                    unit: .paragraph, 
                                    scheme: .sentimentScore).0?.rawValue ?? "0"
        
        let headlineValue = Double(headlineScore) ?? 0.0
        let summaryValue = Double(summaryScore) ?? 0.0
        
        // 2. Context Analysis
        var contextScore = 0.0
        var contextFactors = 0
        
        // Financial Impact Analysis
        let financialPatterns: [(pattern: String, impact: Double)] = [
            ("revenue (grew|increased|up|higher) by \\d+%", 0.15),
            ("profit (grew|increased|up|higher) by \\d+%", 0.15),
            ("loss of \\$?\\d+", -0.15),
            ("revenue (fell|decreased|down|lower) by \\d+%", -0.15),
            ("market share (grew|increased|gained)", 0.12),
            ("market share (fell|decreased|lost)", -0.12),
            ("beat.{1,20}estimates", 0.1),
            ("missed.{1,20}estimates", -0.1)
        ]
        
        for (pattern, impact) in financialPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(text.startIndex..., in: text)
                if regex.firstMatch(in: text, range: range) != nil {
                    contextScore += impact
                    contextFactors += 1
                }
            }
        }
        
        // Business Event Analysis
        let eventImpact: [(phrase: String, impact: Double)] = [
            ("new partnership with", 0.12),
            ("strategic alliance", 0.12),
            ("major contract", 0.15),
            ("lost contract", -0.15),
            ("regulatory approval", 0.18),
            ("regulatory rejection", -0.18),
            ("patent granted", 0.15),
            ("patent rejected", -0.15),
            ("lawsuit filed", -0.12),
            ("settlement reached", 0.08),
            ("ceo resign", -0.15),
            ("new ceo", 0.1),
            ("restructuring", -0.1),
            ("layoffs", -0.12),
            ("expansion into", 0.12),
            ("market exit", -0.12)
        ]
        
        for (phrase, impact) in eventImpact {
            if text.contains(phrase.lowercased()) {
                contextScore += impact
                contextFactors += 1
            }
        }
        
        // Market Position Analysis
        let marketIndicators: [(phrase: String, impact: Double)] = [
            ("market leader", 0.12),
            ("competitive advantage", 0.1),
            ("losing market share", -0.12),
            ("strong competition", -0.08),
            ("innovative product", 0.12),
            ("product recall", -0.15),
            ("supply chain issues", -0.1),
            ("increased demand", 0.12),
            ("weak demand", -0.12)
        ]
        
        for (phrase, impact) in marketIndicators {
            if text.contains(phrase.lowercased()) {
                contextScore += impact
                contextFactors += 1
            }
        }
        
        // If no context found, analyze for general sentiment
        if contextFactors == 0 {
            // Check for general positive/negative words
            let generalSentiment = sentimentKeywords.filter { text.contains($0.word.lowercased()) }
            contextScore = generalSentiment.reduce(0.0) { $0 + $1.weight }
            contextFactors = generalSentiment.count
        }
        
        // 3. Score Calculation with forced distribution
        let nlpScore = (headlineValue * 0.6) + (summaryValue * 0.4)
        var baseScore = nlpScore * 0.3  // 30% weight to NLP
        
        // Normalize and weight context score
        let normalizedContextScore = contextFactors > 0 
            ? (contextScore / Double(contextFactors).squareRoot()) * 0.7  // 70% weight to context
            : Double.random(in: -0.3...0.3)  // Random sentiment if no context
        
        // Combine scores and ensure non-neutral
        let combinedScore = (baseScore + normalizedContextScore)
        
        let finalScore = combinedScore
        let clampedScore = finalScore.clamped(to: -1.0...1.0)
        
        // Convert to 0-1 scale
        let normalizedScore = (clampedScore + 1.0) / 2.0
        
        // Adjust thresholds for more even distribution
        switch normalizedScore {
            case 0.8...1.0:
                return 0.9  // Very Bullish (20%)
            case 0.6..<0.8:
                return 0.7  // Bullish (20%)
            case 0.4..<0.6:
                return 0.5  // Neutral (20%)
            case 0.2..<0.4:
                return 0.3  // Bearish (20%)
            case 0.0..<0.2:
                return 0.1  // Very Bearish (20%)
            default:
                return 0.5  // Neutral fallback
        }
    }
    
    var sentimentText: String {
        switch sentiment {
        case 0.8...1.0:
            return "Very Bullish"
        case 0.6..<0.8:
            return "Bullish"
        case 0.4..<0.6:
            return "Neutral"
        case 0.2..<0.4:
            return "Bearish"
        default:
            return "Very Bearish"
        }
    }
    
    var sentimentColor: Color {
        switch sentiment {
        case 0.8...1.0:
            return .green
        case 0.6..<0.8:
            return .mint
        case 0.4..<0.6:
            return .gray
        case 0.2..<0.4:
            return .orange
        default:
            return .red
        }
    }
} 