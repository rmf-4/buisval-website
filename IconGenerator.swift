import AppKit

class IconGenerator {
    static func generateIcon() {
        do {
            // Get the absolute path to the project directory
            let fileManager = FileManager.default
            let projectPath = "/Users/ryanfrank/Desktop/BuisVal"
            let iconSetPath = URL(fileURLWithPath: projectPath)
                .appendingPathComponent("BuisVal")
                .appendingPathComponent("Assets.xcassets")
                .appendingPathComponent("AppIcon.appiconset")
            
            print("Generating icons at path: \(iconSetPath.path)")
            
            // Create base 1024x1024 image
            let size = NSSize(width: 1024, height: 1024)
            let image = NSImage(size: size)
            
            image.lockFocus()
            
            // Draw background gradient
            let gradient = NSGradient(colors: [
                NSColor(red: 0.1, green: 0.4, blue: 0.8, alpha: 1.0),
                NSColor(red: 0.2, green: 0.6, blue: 0.9, alpha: 1.0)
            ])!
            gradient.draw(in: NSRect(origin: .zero, size: size), angle: 315)
            
            // Draw chart line
            let path = NSBezierPath()
            let points: [(CGFloat, CGFloat)] = [
                (0.2, 0.6),
                (0.3, 0.4),
                (0.4, 0.7),
                (0.5, 0.5),
                (0.6, 0.8),
                (0.7, 0.6),
                (0.8, 0.9)
            ]
            
            path.move(to: NSPoint(x: size.width * points[0].0, y: size.height * points[0].1))
            for point in points.dropFirst() {
                path.line(to: NSPoint(x: size.width * point.0, y: size.height * point.1))
            }
            
            NSColor.white.withAlphaComponent(0.8).setStroke()
            path.lineWidth = 24
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.stroke()
            
            // Draw upward arrow
            let arrowPath = NSBezierPath()
            let arrowSize: CGFloat = 300
            let arrowCenter = NSPoint(x: size.width * 0.5, y: size.height * 0.65)
            
            arrowPath.move(to: NSPoint(x: arrowCenter.x, y: arrowCenter.y - arrowSize * 0.5))
            arrowPath.line(to: NSPoint(x: arrowCenter.x, y: arrowCenter.y + arrowSize * 0.3))
            
            arrowPath.move(to: NSPoint(x: arrowCenter.x - arrowSize * 0.3, y: arrowCenter.y + arrowSize * 0.1))
            arrowPath.line(to: NSPoint(x: arrowCenter.x, y: arrowCenter.y + arrowSize * 0.5))
            arrowPath.line(to: NSPoint(x: arrowCenter.x + arrowSize * 0.3, y: arrowCenter.y + arrowSize * 0.1))
            
            NSColor(red: 0.3, green: 0.9, blue: 0.5, alpha: 1.0).setStroke()
            arrowPath.lineWidth = 32
            arrowPath.lineCapStyle = .round
            arrowPath.lineJoinStyle = .round
            arrowPath.stroke()
            
            // Draw text
            let text = "BuisVal" as NSString
            let font = NSFont.systemFont(ofSize: 240, weight: .heavy)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.white,
                .strokeWidth: -8,
                .strokeColor: NSColor.white.withAlphaComponent(0.3)
            ]
            
            let textSize = text.size(withAttributes: attributes)
            let textRect = NSRect(
                x: (size.width - textSize.width) / 2,
                y: size.height * 0.2,
                width: textSize.width,
                height: textSize.height
            )
            
            text.draw(in: textRect, withAttributes: attributes)
            
            image.unlockFocus()
            
            guard let tiffData = image.tiffRepresentation,
                  let bitmapImage = NSBitmapImageRep(data: tiffData),
                  let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
                throw NSError(domain: "IconGenerator", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create base image"])
            }
            
            // Remove existing icon set directory and create a new one
            if fileManager.fileExists(atPath: iconSetPath.path) {
                try fileManager.removeItem(at: iconSetPath)
            }
            try fileManager.createDirectory(at: iconSetPath, withIntermediateDirectories: true, attributes: nil)
            
            // Modern iOS app icon sizes
            let sizes: [(name: String, size: Int)] = [
                ("Icon-40.png", 40),
                ("Icon-60.png", 60),
                ("Icon-58.png", 58),
                ("Icon-87.png", 87),
                ("Icon-80.png", 80),
                ("Icon-120.png", 120),
                ("Icon-180.png", 180),
                ("Icon-1024.png", 1024)
            ]
            
            // Generate each size
            for (name, size) in sizes {
                let resizedImage = NSImage(size: NSSize(width: size, height: size))
                resizedImage.lockFocus()
                
                NSGraphicsContext.current?.imageInterpolation = .high
                
                image.draw(in: NSRect(origin: .zero, size: resizedImage.size),
                          from: NSRect(origin: .zero, size: image.size),
                          operation: .copy,
                          fraction: 1.0)
                resizedImage.unlockFocus()
                
                guard let resizedTiffData = resizedImage.tiffRepresentation,
                      let resizedBitmap = NSBitmapImageRep(data: resizedTiffData),
                      let pngData = resizedBitmap.representation(using: .png, properties: [:]) else {
                    print("Failed to generate size: \(size)")
                    continue
                }
                
                let imagePath = iconSetPath.appendingPathComponent(name)
                try pngData.write(to: imagePath)
                print("Generated icon: \(name)")
            }
            
            // Create Contents.json
            let contentsJson = """
            {
              "images" : [
                {
                  "filename" : "Icon-40.png",
                  "idiom" : "iphone",
                  "scale" : "2x",
                  "size" : "20x20"
                },
                {
                  "filename" : "Icon-60.png",
                  "idiom" : "iphone",
                  "scale" : "3x",
                  "size" : "20x20"
                },
                {
                  "filename" : "Icon-58.png",
                  "idiom" : "iphone",
                  "scale" : "2x",
                  "size" : "29x29"
                },
                {
                  "filename" : "Icon-87.png",
                  "idiom" : "iphone",
                  "scale" : "3x",
                  "size" : "29x29"
                },
                {
                  "filename" : "Icon-80.png",
                  "idiom" : "iphone",
                  "scale" : "2x",
                  "size" : "40x40"
                },
                {
                  "filename" : "Icon-120.png",
                  "idiom" : "iphone",
                  "scale" : "3x",
                  "size" : "40x40"
                },
                {
                  "filename" : "Icon-120.png",
                  "idiom" : "iphone",
                  "scale" : "2x",
                  "size" : "60x60"
                },
                {
                  "filename" : "Icon-180.png",
                  "idiom" : "iphone",
                  "scale" : "3x",
                  "size" : "60x60"
                },
                {
                  "filename" : "Icon-1024.png",
                  "idiom" : "ios-marketing",
                  "scale" : "1x",
                  "size" : "1024x1024"
                }
              ],
              "info" : {
                "author" : "xcode",
                "version" : 1
              }
            }
            """
            
            try contentsJson.write(to: iconSetPath.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
            print("Icon set generated successfully at: \(iconSetPath.path)")
            
        } catch {
            print("Error generating icons: \(error.localizedDescription)")
        }
    }
}

// Run the generator
IconGenerator.generateIcon() 