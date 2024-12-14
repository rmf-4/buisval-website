//
//  ContentView.swift
//  BuisVal
//
//  Created by ghostmoney on 12/6/24.
//

import SwiftUI

struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var stockService = StockService()
    @State private var selectedSector: MarketSector = .technology
    @State private var showError = false
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var showingSearchResults = false
    @State private var isShowingSingleStock = false
    @State private var selectedStock: Stock? = nil
    @State private var showingNews = false
    
    var body: some View {
        NavigationView {
            mainContent
        }
        .onAppear {
            Task {
                do {
                    try await stockService.fetchStocks(sector: selectedSector)
                } catch {
                    showError = true
                }
            }
        }
    }
    
    private var mainContent: some View {
        ZStack {
            VStack(spacing: 0) {
                searchBar
                searchResultsList
                stocksList
            }
            
            if stockService.isLoading {
                loadingOverlay
            }
        }
        .background(Color(.systemBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .alert("Error", isPresented: $showError) {
            Button("OK") { showError = false }
        } message: {
            Text(stockService.error?.localizedDescription ?? "An unknown error occurred")
        }
    }
    
    private var searchBar: some View {
        HStack(spacing: 12) {
            if isShowingSingleStock {
                backButton
            } else {
                searchField
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    private var backButton: some View {
        Button(action: {
            isShowingSingleStock = false
            showingSearchResults = false
            searchText = ""
            selectedSector = .technology
        }) {
            HStack(spacing: 8) {
                Image(systemName: "chevron.left")
                Text("Back")
            }
            .font(.headline)
            .foregroundColor(.blue)
            .frame(height: 44)
        }
    }
    
    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Search stocks...", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.allCharacters)
                .onSubmit {
                    handleSearchSubmit()
                }
                .onChange(of: searchText) { newValue in
                    Task {
                        if !newValue.isEmpty {
                            await stockService.searchStocks(query: newValue)
                        } else {
                            stockService.searchResults = []
                        }
                        showingSearchResults = !newValue.isEmpty
                    }
                }
        }
    }
    
    private var searchResultsList: some View {
        Group {
            if showingSearchResults && !stockService.searchResults.isEmpty {
                List(stockService.searchResults, id: \.self) { result in
                    Button(action: {
                        handleSearchResultSelection(result)
                    }) {
                        Text(result)
                            .foregroundColor(.primary)
                            .font(.body)
                            .padding(.vertical, 8)
                    }
                }
                .listStyle(PlainListStyle())
                .frame(maxHeight: 280)
                .background(Color(.systemBackground))
            }
        }
    }
    
    private var stocksList: some View {
        List(stockService.stocks) { stock in
            StockRow(stock: stock, onNewsPressed: {
                selectedStock = stock
                showingNews = true
                Task {
                    do {
                        try await stockService.fetchNews(for: stock.symbol)
                    } catch {
                        showError = true
                    }
                }
            })
            .listRowBackground(Color(.secondarySystemBackground))
            .listRowInsets(EdgeInsets())
            .buttonStyle(PlainButtonStyle())
        }
        .listStyle(PlainListStyle())
        .scrollContentBackground(.hidden)
        .sheet(isPresented: $showingNews) {
            NewsView(stock: selectedStock, news: stockService.news)
        }
    }
    
    private var loadingOverlay: some View {
        ZStack {
            Color(.systemBackground)
                .opacity(0.9)
            VStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(1.2)
                Text("Loading stocks...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            HStack(spacing: 16) {
                Text("RMF.lol")
                    .font(.headline)
                    .foregroundColor(.primary)
                if !isShowingSingleStock {
                    Picker("Select Sector", selection: $selectedSector) {
                        ForEach(MarketSector.allCases, id: \.self) { sector in
                            Text(sector.rawValue)
                                .font(.headline)
                                .tag(sector)
                        }
                    }
                    .pickerStyle(.menu)
                    .disabled(stockService.isLoading)
                    .tint(.primary)
                    .onChange(of: selectedSector) { newSector in
                        Task {
                            do {
                                try await stockService.fetchStocks(sector: newSector)
                            } catch {
                                showError = true
                            }
                        }
                    }
                }
                Spacer(minLength: 16)
            }
        }
    }
    
    private func handleSearchSubmit() {
        let symbol = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !symbol.isEmpty {
            Task {
                await stockService.fetchStockBySymbol(symbol)
                await MainActor.run {
                    searchText = ""
                    showingSearchResults = false
                    isShowingSingleStock = true
                }
            }
        }
    }
    
    private func handleSearchResultSelection(_ result: String) {
        let symbol = result.split(separator: " ").first.map(String.init) ?? ""
        Task {
            await stockService.fetchStockBySymbol(symbol)
            await MainActor.run {
                searchText = ""
                showingSearchResults = false
                isShowingSingleStock = true
            }
        }
    }
}

struct StockRow: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var isTargetExpanded = false
    let stock: Stock
    var onNewsPressed: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Main row content
            HStack(alignment: .center, spacing: 12) {
                // Symbol and company
                VStack(alignment: .leading, spacing: 2) {
                    Text(stock.symbol)
                        .font(.headline)
                    Text(stock.companyName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Score and Price only
                HStack(spacing: 12) {
                    // Score
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Score")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\(stock.fundamentalScore, specifier: "%.0f")")
                            .font(.subheadline.bold())
                            .foregroundColor(.blue)
                    }
                    
                    // Price
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("$\(stock.price, specifier: "%.2f")")
                            .font(.subheadline.bold())
                        Button(action: {
                            withAnimation(.spring(response: 0.3)) {
                                isTargetExpanded.toggle()
                            }
                        }) {
                            HStack(spacing: 4) {
                                Text("Future")
                                    .font(.caption)
                                Image(systemName: isTargetExpanded ? "chevron.up" : "chevron.down")
                                    .font(.caption2)
                            }
                            .foregroundColor(.blue)
                        }
                    }
                }
            }
            .frame(height: 44)
            
            // Bottom row with ST/LT and News
            if !isTargetExpanded {
                HStack(spacing: 8) {
                    // ST/LT indicators
                    HStack(spacing: 6) {
                        ProbabilityLabel(title: "ST", value: stock.shortTermBullish)
                        ProbabilityLabel(title: "LT", value: stock.longTermBullish)
                    }
                    
                    Spacer()
                    
                    // News button
                    Button(action: onNewsPressed) {
                        HStack(spacing: 4) {
                            Image(systemName: "newspaper")
                            Text("News")
                                .font(.caption)
                        }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                    }
                }
            }
            
            // Expanded view
            if isTargetExpanded {
                Divider()
                
                // Price targets
                HStack {
                    ForEach(["1M", "6M", "12M", "5Y"], id: \.self) { period in
                        let (price, trend) = getPriceTarget(for: period)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(period)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("$\(price, specifier: "%.2f")")
                                .font(.caption.bold())
                            Text("\(trend >= 0 ? "+" : "")\(trend, specifier: "%.1f")%")
                                .font(.caption2)
                                .foregroundColor(trend >= 0 ? .green : .red)
                        }
                        if period != "5Y" { Spacer() }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
    
    private func getPriceTarget(for period: String) -> (price: Double, trend: Double) {
        switch period {
        case "1M":
            return (stock.price * (1 + stock.shortTermTrend/100), stock.shortTermTrend)
        case "6M":
            return (stock.price * (1 + stock.mediumTermTrend/100), stock.mediumTermTrend)
        case "12M":
            return (stock.price * (1 + stock.longTermTrend/100), stock.longTermTrend)
        case "5Y":
            return (stock.price * (1 + stock.fiveYearTrend/100), stock.fiveYearTrend)
        default:
            return (stock.price, 0)
        }
    }
}

struct ProbabilityLabel: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let value: Double
    
    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text("\(value, specifier: "%.0f")%")
                .font(.caption.bold())
                .foregroundColor(value > 50 ? .green : .red)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(.tertiarySystemBackground))
                .shadow(
                    color: colorScheme == .dark ? .clear : .black.opacity(0.05),
                    radius: 1
                )
        )
    }
}

struct NewsView: View {
    let stock: Stock?
    let news: [NewsItem]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List(news) { item in
                VStack(alignment: .leading, spacing: 8) {
                    Text(item.headline)
                        .font(.headline)
                    
                    Text(item.summary)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                    
                    HStack {
                        Text(item.source)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(Date(timeIntervalSince1970: item.datetime), style: .relative)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Sentiment indicator
                    HStack {
                        Circle()
                            .fill(sentimentColor(item.sentiment))
                            .frame(width: 8, height: 8)
                        Text(sentimentText(item.sentiment))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)
                .onTapGesture {
                    if let url = URL(string: item.url) {
                        UIApplication.shared.open(url)
                    }
                }
            }
            .listStyle(PlainListStyle())
            .navigationTitle("\(stock?.symbol ?? "") News")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func sentimentColor(_ sentiment: Double) -> Color {
        switch sentiment {
        case 0.7...:
            return .green
        case 0.4..<0.7:
            return .yellow
        default:
            return .red
        }
    }
    
    private func sentimentText(_ sentiment: Double) -> String {
        switch sentiment {
        case 0.7...:
            return "Bullish"
        case 0.4..<0.7:
            return "Neutral"
        default:
            return "Bearish"
        }
    }
}

#Preview {
    ContentView()
}
