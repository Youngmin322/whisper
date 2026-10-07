import AppKit
let ink = NSColor(srgbRed: 110/255, green: 97/255, blue: 86/255, alpha: 1)
let neutralInk = NSColor(srgbRed: 0.06, green: 0.06, blue: 0.06, alpha: 1)
let neutralSecondary = NSColor(srgbRed: 0.38, green: 0.38, blue: 0.38, alpha: 1)
for (name, outputName, color) in [("gearshape", "gearshape", ink), ("plus", "plus", ink), ("wifi", "wifi", ink), ("battery.100", "battery.100", ink), ("plus", "plusWhite", NSColor.white), ("gearshape", "gearshapeNeutral", neutralInk), ("wifi", "wifiNeutral", neutralSecondary), ("battery.100", "batteryNeutral", neutralSecondary)] {
    guard let base = NSImage(systemSymbolName: name, accessibilityDescription: nil) else { fatalError(name) }
    let config = NSImage.SymbolConfiguration(pointSize: 96, weight: name == "plus" ? .medium : .regular).applying(NSImage.SymbolConfiguration(paletteColors: [color]))
    let symbol = base.withSymbolConfiguration(config)!
    let size = symbol.size
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * 3), pixelsHigh: Int(size.height * 3), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = size
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    symbol.draw(in: NSRect(origin: .zero, size: size))
    NSGraphicsContext.restoreGraphicsState()
    try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "/private/tmp/whisper-ipad-plugin/" + outputName + ".png"))
    print(outputName, size)
}
