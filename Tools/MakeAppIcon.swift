import AppKit

let arguments = CommandLine.arguments
guard arguments.count == 2 else {
    FileHandle.standardError.write("Usage: make-app-icon OUTPUT_PNG\n".data(using: .utf8)!)
    exit(1)
}

let outputURL = URL(fileURLWithPath: arguments[1])
let canvasSize = NSSize(width: 1024, height: 1024)
let canvas = NSImage(size: canvasSize)

canvas.lockFocusFlipped(true)

let iconRect = NSRect(x: 72, y: 72, width: 880, height: 880)
let iconPath = NSBezierPath(roundedRect: iconRect, xRadius: 228, yRadius: 228)

let gradient = NSGradient(
    colors: [
        NSColor(calibratedRed: 0.22, green: 0.48, blue: 1.00, alpha: 1),
        NSColor(calibratedRed: 0.45, green: 0.28, blue: 0.96, alpha: 1)
    ]
)
gradient?.draw(in: iconPath, angle: -90)

NSColor.white.withAlphaComponent(0.22).setStroke()
iconPath.lineWidth = 18
iconPath.stroke()

let attributes: [NSAttributedString.Key: Any] = [
    .font: NSFont(name: "PingFangSC-Semibold", size: 590)
        ?? NSFont.systemFont(ofSize: 590, weight: .bold),
    .foregroundColor: NSColor.white
]
let glyph = NSAttributedString(string: "插", attributes: attributes)
let glyphRect = glyph.boundingRect(
    with: canvasSize,
    options: [.usesLineFragmentOrigin, .usesFontLeading]
)
let glyphFrame = NSRect(
    x: (canvasSize.width - glyphRect.width) / 2,
    y: (canvasSize.height - glyphRect.height) / 2,
    width: glyphRect.width,
    height: glyphRect.height
)
glyph.draw(in: glyphFrame)

canvas.unlockFocus()

guard
    let tiffData = canvas.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiffData),
    let pngData = bitmap.representation(using: .png, properties: [:])
else {
    FileHandle.standardError.write("Unable to render app icon.\n".data(using: .utf8)!)
    exit(1)
}

do {
    try pngData.write(to: outputURL, options: .atomic)
} catch {
    FileHandle.standardError.write("Unable to write app icon: \(error)\n".data(using: .utf8)!)
    exit(1)
}
