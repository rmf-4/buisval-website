import SwiftUI
import AppKit

struct LogoView: View {
    let mode: AppIconMode
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    mode.backgroundColor1,
                    mode.backgroundColor2
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Abstract stock chart lines
            Path { path in
                let width: CGFloat = 1024
                let height: CGFloat = 1024
                let points: [(CGFloat, CGFloat)] = [
                    (0.2, 0.6),
                    (0.3, 0.4),
                    (0.4, 0.7),
                    (0.5, 0.5),
                    (0.6, 0.8),
                    (0.7, 0.6),
                    (0.8, 0.9)
                ]
                
                path.move(to: CGPoint(x: width * points[0].0, y: height * points[0].1))
                for point in points.dropFirst() {
                    path.addLine(to: CGPoint(x: width * point.0, y: height * point.1))
                }
            }
            .stroke(mode.chartColor, style: StrokeStyle(lineWidth: 12, lineCap: .round, lineJoin: .round))
            .opacity(0.8)
            
            // Main content
            VStack(spacing: 0) {
                // Stock arrow symbol
                Image(systemName: "arrow.up.forward")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 200, height: 200)
                    .foregroundStyle(mode.symbolGradient)
                    .rotationEffect(.degrees(45))
                    .offset(y: 40)
                
                // App name
                Text("BuisVal")
                    .font(.system(size: 180, weight: .heavy, design: .rounded))
                    .foregroundStyle(mode.textGradient)
                    .padding(.top, 40)
            }
            .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
        }
        .frame(width: 1024, height: 1024)
        .ignoresSafeArea()
    }
    
    func snapshot(size: CGSize) -> NSImage? {
        let renderer = ImageRenderer(content: self.frame(width: size.width, height: size.height))
        renderer.scale = 1
        
        guard let cgImage = renderer.cgImage else { return nil }
        return NSImage(cgImage: cgImage, size: size)
    }
    
    func exportIcons(to directory: URL) {
        let sizes: [(name: String, size: CGFloat)] = [
            ("iPhone_20x20@2x.png", 40),
            ("iPhone_20x20@3x.png", 60),
            ("iPhone_29x29@2x.png", 58),
            ("iPhone_29x29@3x.png", 87),
            ("iPhone_40x40@2x.png", 80),
            ("iPhone_40x40@3x.png", 120),
            ("iPhone_60x60@2x.png", 120),
            ("iPhone_60x60@3x.png", 180),
            ("iPad_20x20.png", 20),
            ("iPad_20x20@2x.png", 40),
            ("iPad_29x29.png", 29),
            ("iPad_29x29@2x.png", 58),
            ("iPad_40x40.png", 40),
            ("iPad_40x40@2x.png", 80),
            ("iPad_76x76.png", 76),
            ("iPad_76x76@2x.png", 152),
            ("iPad_83.5x83.5@2x.png", 167),
            ("iOS_Marketing_1024x1024.png", 1024)
        ]
        
        for (name, size) in sizes {
            if let image = snapshot(size: CGSize(width: size, height: size)),
               let tiffData = image.tiffRepresentation,
               let bitmapImage = NSBitmapImageRep(data: tiffData),
               let pngData = bitmapImage.representation(using: .png, properties: [:]) {
                try? pngData.write(to: directory.appendingPathComponent(name))
            }
        }
    }
}

@main
struct IconGenerator: App {
    var body: some Scene {
        WindowGroup {
            LogoView(mode: .regular)
                .onAppear {
                    let fileManager = FileManager.default
                    let currentPath = fileManager.currentDirectoryPath
                    let iconSetPath = URL(fileURLWithPath: currentPath)
                        .appendingPathComponent("BuisVal")
                        .appendingPathComponent("Assets.xcassets")
                        .appendingPathComponent("AppIcon.appiconset")
                    
                    print("Generating icons at: \(iconSetPath.path)")
                    
                    // Clear existing icons
                    try? fileManager.removeItem(at: iconSetPath)
                    try? fileManager.createDirectory(at: iconSetPath, withIntermediateDirectories: true)
                    
                    // Generate new icons
                    LogoView(mode: .regular).exportIcons(to: iconSetPath)
                    print("Icons generated successfully!")
                    
                    // Exit after generating icons
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        exit(0)
                    }
                }
        }
    }
}

enum AppIconMode {
    case regular, dark, tinted
    
    var backgroundColor1: Color {
        switch self {
        case .regular:
            return Color(red: 0.1, green: 0.4, blue: 0.8)  // Deep blue
        case .dark:
            return Color(red: 0.05, green: 0.2, blue: 0.4)  // Darker blue
        case .tinted:
            return Color(red: 0.2, green: 0.5, blue: 0.9)  // Brighter blue
        }
    }
    
    var backgroundColor2: Color {
        switch self {
        case .regular:
            return Color(red: 0.2, green: 0.6, blue: 0.9)  // Lighter blue
        case .dark:
            return Color(red: 0.1, green: 0.3, blue: 0.5)  // Dark blue
        case .tinted:
            return Color(red: 0.3, green: 0.7, blue: 1.0)  // Vibrant blue
        }
    }
    
    var textGradient: LinearGradient {
        LinearGradient(
            colors: [
                .white,
                Color(white: 0.9)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    var symbolGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.3, green: 0.9, blue: 0.5),  // Green
                Color(red: 0.2, green: 0.8, blue: 0.4)   // Darker green
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    var chartColor: Color {
        switch self {
        case .regular, .tinted:
            return .white
        case .dark:
            return Color(white: 0.9)
        }
    }
}

struct LogoView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            LogoView(mode: .regular)
                .previewDisplayName("Regular")
            LogoView(mode: .dark)
                .previewDisplayName("Dark")
            LogoView(mode: .tinted)
                .previewDisplayName("Tinted")
        }
    }
} 