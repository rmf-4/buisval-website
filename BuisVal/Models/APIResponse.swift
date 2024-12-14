struct StockOverview: Codable {
    let symbol: String
    let name: String
    let sector: String?
    let peRatio: String?
    let debtToEquityRatio: String?
    let returnOnEquity: String?
    let operatingCashflow: String?
    
    enum CodingKeys: String, CodingKey {
        case symbol = "Symbol"
        case name = "Name"
        case sector = "Sector"
        case peRatio = "PERatio"
        case debtToEquityRatio = "DebtToEquityRatio"
        case returnOnEquity = "ReturnOnEquityTTM"
        case operatingCashflow = "OperatingCashflowTTM"
    }
}

struct FinnhubRecommendation: Codable {
    let buy: Int
    let sell: Int
    let hold: Int
    let strongBuy: Int
    let strongSell: Int
    
    enum CodingKeys: String, CodingKey {
        case buy = "buy"
        case sell = "sell"
        case hold = "hold"
        case strongBuy = "strongBuy"
        case strongSell = "strongSell"
    }
    
    var bullishScore: Double {
        let total = Double(buy + sell + hold + strongBuy + strongSell)
        guard total > 0 else { return 50.0 }
        
        let weightedScore = (Double(strongBuy) * 100 + 
                           Double(buy) * 75 + 
                           Double(hold) * 50 + 
                           Double(sell) * 25 + 
                           Double(strongSell) * 0) / total
        return weightedScore
    }
}

struct FinnhubSentiment: Codable {
    let sentiment: Double
    let bullishPercent: Double
    
    enum CodingKeys: String, CodingKey {
        case sentiment = "sentiment"
        case bullishPercent = "bullishPercent"
    }
}

struct GlobalQuote: Codable {
    let price: String
    
    enum CodingKeys: String, CodingKey {
        case price = "05. price"
    }
}

struct QuoteResponse: Codable {
    let globalQuote: GlobalQuote
    
    enum CodingKeys: String, CodingKey {
        case globalQuote = "Global Quote"
    }
}

struct FinnhubCompanyProfile: Codable {
    let name: String
    let ticker: String
    let finnhubIndustry: String
    let peRatio: Double?
    let debtToEquity: Double?
    
    func toStockOverview() -> StockOverview {
        return StockOverview(
            symbol: ticker,
            name: name,
            sector: finnhubIndustry,
            peRatio: peRatio.map { String($0) },
            debtToEquityRatio: debtToEquity.map { String($0) },
            returnOnEquity: nil,
            operatingCashflow: nil
        )
    }
}

struct FinnhubQuote: Codable {
    let c: Double?  // Current price
    let pc: Double? // Previous close price
    
    func toQuoteResponse() -> QuoteResponse {
        return QuoteResponse(
            globalQuote: GlobalQuote(price: String(c ?? 0.0))
        )
    }
} 