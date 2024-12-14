import Foundation
import Combine

class StockService: ObservableObject {
    @Published var stocks: [Stock] = []
    @Published var searchResults: [String] = []
    @Published var error: APIError?
    @Published var isLoading = false
    @Published var news: [NewsItem] = []
    
    private let webSocketManager = WebSocketManager()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        webSocketManager.onPriceUpdate = { [weak self] symbol, price in
            self?.updateStockPrice(symbol: symbol, newPrice: price)
        }
    }
    
    func fetchStocks(sector: MarketSector) async throws {
        isLoading = true
        error = nil
        
        let symbols = getSymbolsForSector(sector)
        var newStocks: [Stock] = []
        
        for symbol in symbols {
            do {
                async let overview = fetchStockOverview(symbol: symbol)
                async let quote = fetchStockQuote(symbol: symbol)
                async let recommendation = fetchRecommendation(symbol: symbol)
                async let sentiment = fetchSentiment(symbol: symbol)
                
                let (overviewData, quoteData, recommendationData, sentimentData) = try await (overview, quote, recommendation, sentiment)
                
                if let stock = createStock(from: overviewData, quote: quoteData, recommendation: recommendationData, sentiment: sentimentData) {
                    newStocks.append(stock)
                }
            } catch {
                print("Error fetching stock \(symbol): \(error)")
                continue // Continue with other stocks if one fails
            }
        }
        
        // For top picks, rank and filter the stocks
        if sector == .topPicks {
            stocks = rankTopPicks(stocks: newStocks)
        } else {
            // Sort stocks by a combined score of fundamental score and price target potential
            stocks = newStocks.sorted { stock1, stock2 in
                let targetPotential1 = ((stock1.priceTarget - stock1.price) / stock1.price) * 100
                let targetPotential2 = ((stock2.priceTarget - stock2.price) / stock2.price) * 100
                
                let combinedScore1 = (stock1.fundamentalScore * 0.7) + (targetPotential1 * 0.3)
                let combinedScore2 = (stock2.fundamentalScore * 0.7) + (targetPotential2 * 0.3)
                
                return combinedScore1 > combinedScore2
            }
        }
        
        isLoading = false
    }
    
    private func fetchStockOverview(symbol: String) async throws -> StockOverview {
        let urlString = "\(APIConfig.finnhubBaseURL)/stock/profile2?symbol=\(symbol)&token=\(APIConfig.finnhubKey)"
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        // Debug print
        print("Overview Response for \(symbol): \(httpResponse.statusCode)")
        if let jsonString = String(data: data, encoding: .utf8) {
            print(jsonString)
        }
        
        if httpResponse.statusCode == 200 {
            do {
                let decoder = JSONDecoder()
                let profile = try decoder.decode(FinnhubCompanyProfile.self, from: data)
                return profile.toStockOverview()
            } catch {
                print("Decoding error for \(symbol): \(error)")
                throw APIError.decodingError(error)
            }
        } else if httpResponse.statusCode == 429 {
            throw APIError.rateLimitExceeded
        } else {
            throw APIError.serverError("Status code: \(httpResponse.statusCode)")
        }
    }
    
    private func fetchStockQuote(symbol: String) async throws -> QuoteResponse {
        let urlString = "\(APIConfig.finnhubBaseURL)/quote?symbol=\(symbol)&token=\(APIConfig.finnhubKey)"
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            do {
                let decoder = JSONDecoder()
                let quote = try decoder.decode(FinnhubQuote.self, from: data)
                return quote.toQuoteResponse()
            } catch {
                print("Quote decoding error for \(symbol): \(error)")
                throw APIError.decodingError(error)
            }
        } else if httpResponse.statusCode == 429 {
            throw APIError.rateLimitExceeded
        } else {
            throw APIError.serverError("Status code: \(httpResponse.statusCode)")
        }
    }
    
    private func createStock(from overview: StockOverview, quote: QuoteResponse, recommendation: FinnhubRecommendation, sentiment: FinnhubSentiment) -> Stock? {
        guard let price = Double(quote.globalQuote.price) else { return nil }
        
        return Stock(
            symbol: overview.symbol,
            companyName: overview.name,
            sector: overview.sector ?? "Unknown",
            price: price,
            peRatio: Double(overview.peRatio ?? ""),
            debtToEquity: Double(overview.debtToEquityRatio ?? ""),
            roe: Double(overview.returnOnEquity?.replacingOccurrences(of: "%", with: "") ?? ""),
            cashFlow: Double(overview.operatingCashflow ?? ""),
            analystScore: recommendation.bullishScore,
            shortTermSentiment: sentiment.bullishPercent,
            longTermSentiment: recommendation.bullishScore
        )
    }
    
    private func fetchRecommendation(symbol: String) async throws -> FinnhubRecommendation {
        let urlString = "\(APIConfig.finnhubBaseURL)/stock/recommendation?symbol=\(symbol)&token=\(APIConfig.finnhubKey)"
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            do {
                let decoder = JSONDecoder()
                let recommendations = try decoder.decode([FinnhubRecommendation].self, from: data)
                return recommendations.first ?? FinnhubRecommendation(buy: 0, sell: 0, hold: 0, strongBuy: 0, strongSell: 0)
            } catch {
                print("Recommendation decoding error for \(symbol): \(error)")
                // Return default recommendation instead of throwing
                return FinnhubRecommendation(buy: 0, sell: 0, hold: 0, strongBuy: 0, strongSell: 0)
            }
        } else if httpResponse.statusCode == 429 {
            throw APIError.rateLimitExceeded
        } else {
            // Return default recommendation instead of throwing
            return FinnhubRecommendation(buy: 0, sell: 0, hold: 0, strongBuy: 0, strongSell: 0)
        }
    }
    
    private func fetchSentiment(symbol: String) async throws -> FinnhubSentiment {
        // For now, return mock sentiment data since the endpoint might be premium
        return FinnhubSentiment(sentiment: 0.6, bullishPercent: Double.random(in: 40...60))
    }
    
    func startRealTimeUpdates() {
        // First disconnect any existing connection
        webSocketManager.disconnect()
        
        // Then start a new connection with current stocks
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.webSocketManager.connect()
            self?.stocks.forEach { stock in
                self?.webSocketManager.subscribe(to: stock.symbol)
            }
        }
    }
    
    func stopRealTimeUpdates() {
        webSocketManager.disconnect()
    }
    
    private func updateStockPrice(symbol: String, newPrice: Double) {
        if let index = stocks.firstIndex(where: { $0.symbol == symbol }) {
            var updatedStock = stocks[index]
            updatedStock.updatePrice(newPrice)
            stocks[index] = updatedStock
        }
    }
    
    private func getSymbolsForSector(_ sector: MarketSector) -> [String] {
        switch sector {
        case .topPicks:
            // Top companies across sectors that we'll analyze
            return ["AAPL", "MSFT", "GOOGL", "AMZN", "META", "NVDA", "AMD", "TSLA", "JPM", "V", 
                    "JNJ", "PG", "XOM", "BAC", "DIS", "NFLX", "ADBE", "CSCO", "INTC", "CRM"]
        case .technology:
            return ["AAPL", "MSFT", "GOOGL", "META", "NVDA", "ADBE", "CRM", "INTC", "AMD", "CSCO", 
                    "ORCL", "AVGO", "ACN", "IBM", "NOW", "QCOM", "ADI", "AMAT", "MU", "PYPL"]
        case .healthcare:
            return ["JNJ", "UNH", "PFE", "ABT", "TMO", "MRK", "DHR", "BMY", "ABBV", "LLY", 
                    "AMGN", "CVS", "MDT", "ISRG", "GILD", "VRTX", "ZTS", "BSX", "BDX", "HUM"]
        case .financials:
            return ["JPM", "BAC", "WFC", "C", "GS", "MS", "BLK", "SCHW", "AXP", "USB", 
                    "PNC", "TFC", "COF", "BK", "SPGI", "CME", "ICE", "CB", "MMC", "AON"]
        case .consumerDiscretionary:
            return ["AMZN", "TSLA", "HD", "MCD", "NKE", "SBUX", "TGT", "LOW", "BKNG", "MAR", 
                    "F", "GM", "ROST", "TJX", "YUM", "DPZ", "EBAY", "BBY", "DRI", "CMG"]
        case .consumerStaples:
            return ["PG", "KO", "PEP", "WMT", "COST", "PM", "MO", "EL", "CL", "KMB", 
                    "GIS", "K", "SYY", "STZ", "KHC", "HSY", "TSN", "CAG", "CLX", "CHD"]
        case .industrials:
            return ["HON", "UPS", "BA", "CAT", "DE", "LMT", "RTX", "UNP", "MMM", "GE", 
                    "EMR", "ETN", "NSC", "CSX", "WM", "ITW", "FDX", "PH", "ROK", "CMI"]
        case .energy:
            return ["XOM", "CVX", "COP", "SLB", "EOG", "MPC", "PSX", "VLO", "PXD", "OXY", 
                    "KMI", "WMB", "HAL", "DVN", "BKR", "HES", "OKE", "CVI", "MRO", "APA"]
        case .materials:
            return ["LIN", "APD", "ECL", "SHW", "DD", "NEM", "FCX", "DOW", "NUE", "VMC", 
                    "MLM", "CF", "ALB", "FMC", "MOS", "PPG", "EMN", "IFF", "CE", "AVY"]
        case .utilities:
            return ["NEE", "DUK", "SO", "D", "AEP", "SRE", "EXC", "XEL", "PCG", "WEC", 
                    "ES", "ED", "ETR", "PEG", "DTE", "FE", "AEE", "CMS", "CNP", "EIX"]
        case .realEstate:
            return ["PLD", "AMT", "CCI", "EQIX", "PSA", "O", "WELL", "DLR", "AVB", "EQR", 
                    "SPG", "VICI", "WY", "ARE", "VTR", "BXP", "UDR", "IRM", "HST", "KIM"]
        }
    }
    
    func searchSymbols(query: String) async throws {
        guard query.count >= 1 else {
            searchResults = []
            return
        }
        
        let urlString = "\(APIConfig.finnhubBaseURL)/search?q=\(query)&token=\(APIConfig.finnhubKey)"
        guard let encodedString = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: encodedString) else {
            throw APIError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            struct SearchResponse: Codable {
                let result: [SearchResult]
            }
            
            struct SearchResult: Codable {
                let symbol: String
                let description: String
            }
            
            do {
                let decoder = JSONDecoder()
                let searchResponse = try decoder.decode(SearchResponse.self, from: data)
                DispatchQueue.main.async {
                    self.searchResults = searchResponse.result
                        .filter { $0.symbol.contains(".") == false } // Filter out non-stock symbols
                        .map { "\($0.symbol) - \($0.description)" }
                }
            } catch {
                print("Search decoding error: \(error)")
                throw APIError.decodingError(error)
            }
        } else if httpResponse.statusCode == 429 {
            throw APIError.rateLimitExceeded
        } else {
            throw APIError.serverError("Status code: \(httpResponse.statusCode)")
        }
    }
    
    @MainActor
    func fetchStockBySymbol(_ symbol: String) async {
        isLoading = true
        error = nil
        
        do {
            async let overview = fetchStockOverview(symbol: symbol)
            async let quote = fetchStockQuote(symbol: symbol)
            async let recommendation = fetchRecommendation(symbol: symbol)
            async let sentiment = fetchSentiment(symbol: symbol)
            
            let (overviewData, quoteData, recommendationData, sentimentData) = try await (overview, quote, recommendation, sentiment)
            
            if let stock = createStock(from: overviewData, quote: quoteData, recommendation: recommendationData, sentiment: sentimentData) {
                // Replace or add the stock
                if let index = stocks.firstIndex(where: { $0.symbol == symbol }) {
                    stocks[index] = stock
                } else {
                    stocks.append(stock)
                }
                
                // Start real-time updates
                webSocketManager.subscribe(to: symbol)
            }
        } catch {
            self.error = error as? APIError ?? .networkError(error)
        }
        
        isLoading = false
    }
    
    @MainActor
    func fetchNews(for symbol: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        let urlString = "\(APIConfig.finnhubBaseURL)/company-news?symbol=\(symbol)&from=\(oneMonthAgo)&to=\(today)&token=\(APIConfig.finnhubKey)"
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            struct FinnhubNewsItem: Codable {
                let category: String?
                let datetime: Int
                let headline: String
                let id: Int
                let image: String?
                let related: String?
                let source: String
                let summary: String
                let url: String
            }
            
            do {
                let decoder = JSONDecoder()
                var finnhubNews = try decoder.decode([FinnhubNewsItem].self, from: data)
                
                // Sort by date (newest first) and take top 20
                finnhubNews.sort { $0.datetime > $1.datetime }
                finnhubNews = Array(finnhubNews.prefix(20))
                
                // Convert to our NewsItem model with sentiment analysis
                news = finnhubNews.map { item in
                    let sentiment = analyzeSentiment(text: item.headline + " " + item.summary)
                    let trustScore = calculateTrustScore(source: item.source)
                    
                    return NewsItem(
                        id: item.id,
                        headline: item.headline,
                        summary: item.summary,
                        url: item.url,
                        datetime: TimeInterval(item.datetime),
                        source: item.source,
                        sentiment: sentiment,
                        trustScore: trustScore
                    )
                }
            } catch {
                throw APIError.decodingError(error)
            }
        } else if httpResponse.statusCode == 429 {
            throw APIError.rateLimitExceeded
        } else {
            throw APIError.serverError("Status code: \(httpResponse.statusCode)")
        }
    }
    
    private func analyzeSentiment(text: String) -> Double {
        // Simple keyword-based sentiment analysis
        let bullishKeywords = ["upgrade", "beat", "growth", "positive", "strong", "higher", "success", "profit"]
        let bearishKeywords = ["downgrade", "miss", "decline", "negative", "weak", "lower", "loss", "risk"]
        
        let words = text.lowercased().split(separator: " ")
        var sentiment = 0.5 // Neutral starting point
        
        for word in words {
            if bullishKeywords.contains(String(word)) {
                sentiment += 0.1
            } else if bearishKeywords.contains(String(word)) {
                sentiment -= 0.1
            }
        }
        
        // Clamp sentiment between 0 and 1
        return sentiment.clamped(to: 0...1)
    }
    
    private func calculateTrustScore(source: String) -> Double {
        // Define trusted sources and their scores
        let trustedSources: [String: Double] = [
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
        
        return trustedSources[source] ?? 0.4
    }
    
    private var today: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    
    private var oneMonthAgo: String {
        let date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    @MainActor
    func searchStocks(query: String) async {
        // Implement stock search logic here
        // Update searchResults property with the results
    }
    
    private func rankTopPicks(stocks: [Stock]) -> [Stock] {
        // Calculate composite scores for each stock
        let rankedStocks = stocks.map { stock -> (Stock, Double) in
            // Fundamental score (0-100)
            let fundamentalScore = stock.fundamentalScore
            
            // Price target potential (-100 to +100)
            let priceTargetScore = stock.priceTargetPercentage.clamped(to: -100...100)
            
            // Sentiment scores (0-100)
            let shortTermScore = stock.shortTermBullish
            let longTermScore = stock.longTermBullish
            
            // Calculate weighted composite score
            let compositeScore = (
                fundamentalScore * 0.3 +           // 30% weight on fundamentals
                priceTargetScore * 0.3 +          // 30% weight on price target
                shortTermScore * 0.2 +            // 20% weight on short-term sentiment
                longTermScore * 0.2               // 20% weight on long-term sentiment
            )
            
            return (stock, compositeScore)
        }
        
        // Sort by composite score and take top 5
        return rankedStocks
            .sorted { $0.1 > $1.1 }  // Sort by score descending
            .prefix(5)                // Take top 5
            .map { $0.0 }            // Extract just the stock
    }
} 