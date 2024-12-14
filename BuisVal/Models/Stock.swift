import Foundation

struct Stock: Identifiable, Codable {
    let id: UUID
    let symbol: String
    let companyName: String
    let sector: String
    private(set) var price: Double
    let peRatio: Double?
    let debtToEquity: Double?
    let roe: Double?
    let cashFlow: Double?
    let analystScore: Double
    let shortTermSentiment: Double
    let longTermSentiment: Double
    let priceTarget: Double
    let timeframe: String
    let shortTermTrend: Double
    let mediumTermTrend: Double
    let longTermTrend: Double
    let fiveYearTrend: Double
    
    init(id: UUID = UUID(), symbol: String, companyName: String, sector: String, 
         price: Double, peRatio: Double?, debtToEquity: Double?, roe: Double?, 
         cashFlow: Double?, analystScore: Double, shortTermSentiment: Double, 
         longTermSentiment: Double) {
        self.id = id
        self.symbol = symbol
        self.companyName = companyName
        self.sector = sector
        self.price = price
        self.peRatio = peRatio
        self.debtToEquity = debtToEquity
        self.roe = roe
        self.cashFlow = cashFlow
        self.analystScore = analystScore
        self.shortTermSentiment = shortTermSentiment
        self.longTermSentiment = longTermSentiment
        
        // Calculate different term trends based on sentiment and analyst scores
        self.shortTermTrend = (shortTermSentiment - 50) * 0.2  // 20% max movement
        self.mediumTermTrend = (shortTermSentiment + longTermSentiment - 100) * 0.3  // 30% max movement
        self.longTermTrend = (analystScore - 50) * 0.5  // 50% max movement
        
        // Select the most significant trend for the price target
        let shortTermTarget = price * (1 + self.shortTermTrend/100)
        let mediumTermTarget = price * (1 + self.mediumTermTrend/100)
        let longTermTarget = price * (1 + self.longTermTrend/100)
        
        // Choose the most significant movement as the primary target
        let shortTermChange = abs((shortTermTarget - price) / price)
        let mediumTermChange = abs((mediumTermTarget - price) / price)
        let longTermChange = abs((longTermTarget - price) / price)
        
        if shortTermChange >= mediumTermChange && shortTermChange >= longTermChange {
            self.priceTarget = shortTermTarget
            self.timeframe = "1M"
        } else if mediumTermChange >= longTermChange {
            self.priceTarget = mediumTermTarget
            self.timeframe = "6M"
        } else {
            self.priceTarget = longTermTarget
            self.timeframe = "12M"
        }
        
        // Calculate 5-year trend based on long-term sentiment and analyst score
        self.fiveYearTrend = (longTermSentiment + analystScore - 100) * 1.0  // 100% max movement
    }
    
    mutating func updatePrice(_ newPrice: Double) {
        price = newPrice
    }
    
    var fundamentalScore: Double {
        return analystScore
    }
    
    var shortTermBullish: Double {
        return shortTermSentiment
    }
    
    var longTermBullish: Double {
        return longTermSentiment
    }
    
    var priceTargetPercentage: Double {
        return ((priceTarget - price) / price) * 100
    }
}
