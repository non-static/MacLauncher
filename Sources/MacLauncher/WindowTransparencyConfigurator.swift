import AppKit
import SwiftUI

struct WindowTransparencyConfigurator: NSViewRepresentable {
    private static let fixedWindowSize = NSSize(width: 860, height: 620)
    private static let cornerRadius: CGFloat = 22

    func makeNSView(context: Context) -> NSView {
        let view = NSView()

        DispatchQueue.main.async {
            configure(window: view.window)
        }

        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configure(window: nsView.window)
        }
    }

    private func configure(window: NSWindow?) {
        guard let window else {
            return
        }

        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.title = ""
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.minSize = Self.fixedWindowSize
        window.maxSize = Self.fixedWindowSize
        window.contentMinSize = Self.fixedWindowSize
        window.contentMaxSize = Self.fixedWindowSize
        window.setContentSize(Self.fixedWindowSize)

        disableTrafficLightButtons(in: window)
        window.styleMask.remove([.titled, .closable, .miniaturizable, .resizable])
        disableTrafficLightButtons(in: window)
        applyRoundedCorners(to: window)
        window.invalidateShadow()
    }

    private func disableTrafficLightButtons(in window: NSWindow) {
        [
            NSWindow.ButtonType.closeButton,
            .miniaturizeButton,
            .zoomButton
        ].forEach { buttonType in
            let button = window.standardWindowButton(buttonType)
            button?.isHidden = true
            button?.isEnabled = false
        }
    }

    private func applyRoundedCorners(to window: NSWindow) {
        guard let contentView = window.contentView else {
            return
        }

        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.clear.cgColor
        contentView.layer?.cornerRadius = Self.cornerRadius
        contentView.layer?.cornerCurve = .continuous
        contentView.layer?.masksToBounds = true
    }
}
