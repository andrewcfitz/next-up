import AppKit

// Usage: swift Scripts/make-icon.swift <output.png>
let size = 1024
guard CommandLine.arguments.count > 1 else {
    FileHandle.standardError.write(Data("usage: make-icon.swift <output.png>\n".utf8))
    exit(1)
}

// AppKit bitmap contexts refuse 24-bit RGB, so draw into an opaque (noneSkipLast) CGContext instead.
guard let cg = CGContext(
    data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
) else { exit(1) }
let ctx = NSGraphicsContext(cgContext: cg, flipped: false)

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = ctx

NSColor(srgbRed: 0x2F / 255, green: 0x5D / 255, blue: 0x50 / 255, alpha: 1).setFill()
NSRect(x: 0, y: 0, width: size, height: size).fill()

let config = NSImage.SymbolConfiguration(pointSize: 600, weight: .regular)
guard let raw = NSImage(systemSymbolName: "tent.fill", accessibilityDescription: nil)?
    .withSymbolConfiguration(config) else { exit(1) }

// Symbols draw black by default; fill white through the glyph's own alpha.
let symbol = NSImage(size: raw.size, flipped: false) { rect in
    raw.draw(in: rect)
    NSColor.white.set()
    rect.fill(using: .sourceIn)
    return true
}

// Fit the glyph to about 60% of the canvas whatever its natural aspect ratio.
let target = CGFloat(size) * 0.6
let scale = min(target / symbol.size.width, target / symbol.size.height)
let w = symbol.size.width * scale, h = symbol.size.height * scale
symbol.draw(in: NSRect(x: (CGFloat(size) - w) / 2, y: (CGFloat(size) - h) / 2, width: w, height: h))

NSGraphicsContext.restoreGraphicsState()

guard let image = cg.makeImage(),
      let dest = CGImageDestinationCreateWithURL(
          URL(fileURLWithPath: CommandLine.arguments[1]) as CFURL, "public.png" as CFString, 1, nil)
else { exit(1) }
CGImageDestinationAddImage(dest, image, nil)
guard CGImageDestinationFinalize(dest) else { exit(1) }
