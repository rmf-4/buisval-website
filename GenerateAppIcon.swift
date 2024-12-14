import SwiftUI

@main
struct GenerateAppIcon: App {
    var body: some Scene {
        WindowGroup {
            LogoView(mode: .regular)
                .onAppear {
                    if let projectURL = Bundle.main.resourceURL?.deletingLastPathComponent().deletingLastPathComponent() {
                        let iconSetPath = projectURL
                            .appendingPathComponent("BuisVal")
                            .appendingPathComponent("Assets.xcassets")
                            .appendingPathComponent("AppIcon.appiconset")
                        
                        // Clear existing icons
                        try? FileManager.default.removeItem(at: iconSetPath)
                        try? FileManager.default.createDirectory(at: iconSetPath, withIntermediateDirectories: true)
                        
                        // Generate new icons
                        LogoView(mode: .regular).exportIcon(to: iconSetPath)
                        print("Icons generated at: \(iconSetPath.path)")
                        
                        // Exit after generating icons
                        exit(0)
                    }
                }
        }
    }
} 