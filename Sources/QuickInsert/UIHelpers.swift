import AppKit

func makeIconButton(
    symbolName: String,
    tooltip: String,
    target: AnyObject?,
    action: Selector
) -> NSButton {
    let image = NSImage(
        systemSymbolName: symbolName,
        accessibilityDescription: tooltip
    ) ?? NSImage()
    let button = NSButton(image: image, target: target, action: action)
    button.translatesAutoresizingMaskIntoConstraints = false
    button.isBordered = false
    button.bezelStyle = .texturedRounded
    button.toolTip = tooltip
    button.contentTintColor = .secondaryLabelColor
    button.setContentHuggingPriority(.required, for: .horizontal)
    button.setContentCompressionResistancePriority(.required, for: .horizontal)
    NSLayoutConstraint.activate([
        button.widthAnchor.constraint(equalToConstant: 30),
        button.heightAnchor.constraint(equalToConstant: 30)
    ])
    return button
}

func makeTextLabel(
    _ text: String,
    size: CGFloat,
    weight: NSFont.Weight = .regular,
    color: NSColor = .labelColor
) -> NSTextField {
    let label = NSTextField(labelWithString: text)
    label.translatesAutoresizingMaskIntoConstraints = false
    label.font = NSFont.systemFont(ofSize: size, weight: weight)
    label.textColor = color
    label.lineBreakMode = .byTruncatingTail
    return label
}

func makeSeparator() -> NSBox {
    let separator = NSBox()
    separator.translatesAutoresizingMaskIntoConstraints = false
    separator.boxType = .separator
    return separator
}

func makeScrollView(for documentView: NSView) -> NSScrollView {
    let scrollView = NSScrollView()
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    scrollView.drawsBackground = false
    scrollView.hasVerticalScroller = true
    scrollView.hasHorizontalScroller = false
    scrollView.autohidesScrollers = true
    scrollView.documentView = documentView
    return scrollView
}

final class ClickableTableView: NSTableView {
    var onClickRow: ((Int) -> Void)?

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)

        let point = convert(event.locationInWindow, from: nil)
        let row = row(at: point)
        if row >= 0, event.clickCount == 1 {
            onClickRow?(row)
        }
    }
}
