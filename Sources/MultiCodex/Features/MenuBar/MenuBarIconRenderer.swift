import AppKit

/// Renders a dynamic menu bar icon showing current account usage.
enum MenuBarIconRenderer {
    private static let size = NSSize(width: 18, height: 18)

    static func render(
        fiveHourProgress: Double,
        weeklyProgress: Double,
        fiveHourUsedPercent: Double?,
        weeklyUsedPercent: Double?,
        isStale: Bool
    ) -> NSImage {
        let alpha: CGFloat = isStale ? 0.48 : 1
        let fiveHour = normalizedProgress(fiveHourProgress)
        let weekly = normalizedProgress(weeklyProgress)
        let fiveHourColor = color(for: fiveHourUsedPercent)
        let weeklyColor = color(for: weeklyUsedPercent)

        // The handler runs at draw time, so `labelColor` follows the current menu bar
        // appearance (light, dark, or tinted wallpaper) instead of the one at creation.
        let image = NSImage(size: size, flipped: false) { _ in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            context.setShouldAntialias(true)

            drawUsageBar(
                in: CGRect(x: 2.5, y: 10.5, width: 13, height: 3.5),
                progress: fiveHour,
                accent: fiveHourColor,
                alpha: alpha,
                context: context
            )
            drawUsageBar(
                in: CGRect(x: 2.5, y: 4.5, width: 13, height: 3.5),
                progress: weekly,
                accent: weeklyColor,
                alpha: alpha,
                context: context
            )

            if isStale {
                context.setFillColor(NSColor.systemOrange.withAlphaComponent(0.95).cgColor)
                context.fillEllipse(in: CGRect(x: 13, y: 13, width: 3, height: 3))
            }
            return true
        }
        image.isTemplate = false
        image.accessibilityDescription = accessibilityDescription(
            fiveHourUsedPercent: fiveHourUsedPercent,
            weeklyUsedPercent: weeklyUsedPercent,
            isStale: isStale
        )
        return image
    }

    static func accessibilityDescription(
        fiveHourUsedPercent: Double?,
        weeklyUsedPercent: Double?,
        isStale: Bool
    ) -> String {
        func part(_ label: String, _ percent: Double?) -> String {
            guard let percent else { return "\(label) unknown" }
            return "\(label) \(Int(percent.rounded()))% used"
        }
        var text = "MultiCodex: \(part("5-hour", fiveHourUsedPercent)), \(part("weekly", weeklyUsedPercent))"
        if isStale { text += ", needs attention" }
        return text
    }

    private static func drawUsageBar(
        in rect: CGRect,
        progress: CGFloat,
        accent: NSColor,
        alpha: CGFloat,
        context: CGContext
    ) {
        let radius = rect.height / 2
        let track = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
        context.addPath(track)
        context.setFillColor(NSColor.labelColor.withAlphaComponent(alpha * 0.18).cgColor)
        context.fillPath()

        guard progress > 0 else { return }

        let fillRect = CGRect(
            x: rect.minX,
            y: rect.minY,
            width: max(rect.height, rect.width * progress),
            height: rect.height
        )
        let fill = CGPath(roundedRect: fillRect, cornerWidth: radius, cornerHeight: radius, transform: nil)
        context.addPath(fill)
        context.setFillColor(accent.withAlphaComponent(alpha).cgColor)
        context.fillPath()
    }

    private static func normalizedProgress(_ progress: Double) -> CGFloat {
        CGFloat(min(1, max(0, progress)))
    }

    private static func color(for percent: Double?) -> NSColor {
        guard percent != nil else { return NSColor.systemGray }
        switch UsageLevel.from(usedPercent: percent) {
        case .critical: return NSColor.systemRed
        case .warning: return NSColor.systemOrange
        case .normal: return NSColor.systemPurple
        }
    }
}
