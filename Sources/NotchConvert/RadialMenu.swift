import AppKit
import SwiftUI

struct RadialGeometry {
    static let formats = ["pdf", "jpeg", "png", "pptx", "zip"]
    static let size: CGFloat = 360
    static let innerRadius: CGFloat = 68
    static let outerRadius: CGFloat = 156
    static let gap: Double = 0.055
    static let step = 2 * Double.pi / Double(formats.count)

    static func startAngle(_ index: Int) -> Double {
        -.pi / 2 - step / 2 + Double(index) * step + gap / 2
    }
    static func endAngle(_ index: Int) -> Double { startAngle(index) + step - gap }

    // Coordinates are flipped (positive y down) to match SwiftUI's arcs and positions.
    static func format(at point: CGPoint) -> String? {
        let dx = Double(point.x - size / 2)
        let dy = Double(point.y - size / 2)
        let radius = hypot(dx, dy)
        guard radius >= Double(innerRadius), radius <= Double(outerRadius) else { return nil }
        let tau = 2 * Double.pi
        let angle = (atan2(dy, dx) + .pi / 2 + step / 2 + tau).truncatingRemainder(dividingBy: tau)
        let index = min(Int(angle / step), formats.count - 1)
        let within = angle - Double(index) * step
        guard within >= gap / 2, within <= step - gap / 2 else { return nil }
        return formats[index]
    }
}

private struct RingSegment: Shape {
    var index: Int
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let start = Angle(radians: RadialGeometry.startAngle(index))
        let end = Angle(radians: RadialGeometry.endAngle(index))
        var path = Path()
        path.addArc(center: center, radius: RadialGeometry.outerRadius,
                    startAngle: start, endAngle: end, clockwise: false)
        path.addArc(center: center, radius: RadialGeometry.innerRadius,
                    startAngle: end, endAngle: start, clockwise: true)
        path.closeSubpath()
        return path
    }
}

final class RadialState: ObservableObject {
    @Published var available: [String] = []
    @Published var highlighted: String?
    @Published var filename = ""
    @Published var fileCount = 0
    @Published var inspecting = true
    @Published var note = ""
}

private struct RadialMenuView: View {
    @ObservedObject var state: RadialState
    let symbols = ["doc.richtext", "photo", "photo.on.rectangle", "rectangle.stack", "archivebox"]

    var body: some View {
        ZStack {
            Circle().fill(Color.black.opacity(0.97))
                .frame(width: 320, height: 320)
                .overlay(Circle().stroke(Color.white.opacity(0.16), lineWidth: 1))
            ForEach(Array(RadialGeometry.formats.enumerated()), id: \.offset) { index, format in
                let enabled = state.available.contains(format)
                let selected = enabled && state.highlighted == format
                RingSegment(index: index)
                    .fill(selected ? Color.white : Color.white.opacity(enabled ? 0.08 : 0.025))
                    .overlay(RingSegment(index: index).stroke(Color.white.opacity(enabled ? 0.17 : 0.05), lineWidth: 1))
                VStack(spacing: 7) {
                    Image(systemName: symbols[index]).font(.system(size: 21, weight: .light))
                    Text(format.uppercased()).font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(selected ? Color.black : Color.white.opacity(enabled ? 0.92 : 0.25))
                .position(labelPosition(index))
                .accessibilityLabel("\(format.uppercased())로 변환")
            }
            VStack(spacing: 5) {
                if state.inspecting {
                    ProgressView().controlSize(.small).tint(.white)
                    Text("확인 중").font(.system(size: 10))
                } else if let highlighted = state.highlighted {
                    Image(systemName: "arrow.down").font(.system(size: 19, weight: .light))
                    Text(highlighted.uppercased()).font(.system(size: 13, weight: .semibold))
                    Text("놓아서 변환").font(.system(size: 10))
                } else {
                    Image(systemName: state.available.isEmpty ? "exclamationmark" : "doc")
                        .font(.system(size: 19, weight: .light))
                    Text(state.fileCount > 1 ? "\(state.fileCount)개 파일" : state.filename)
                        .font(.system(size: 10)).lineLimit(1).truncationMode(.middle)
                    Text(state.available.isEmpty ? "변환 불가" : "형식에 놓기")
                        .font(.system(size: 10)).foregroundStyle(Color.white.opacity(0.55))
                }
            }
            .foregroundStyle(Color.white).frame(width: 108, height: 108)
            .help(state.note.isEmpty ? "결과는 원본 옆에 저장됩니다." : state.note)
        }
        .frame(width: RadialGeometry.size, height: RadialGeometry.size)
        .allowsHitTesting(false)
        .preferredColorScheme(.dark)
    }
    private func labelPosition(_ index: Int) -> CGPoint {
        let angle = -.pi / 2 + Double(index) * RadialGeometry.step
        let radius = 112.0
        return CGPoint(x: Double(RadialGeometry.size / 2) + cos(angle) * radius,
                       y: Double(RadialGeometry.size / 2) + sin(angle) * radius)
    }
}

private final class RadialDropView: NSView {
    let state: RadialState
    var expectedURLs: [URL] = []
    var receive: (([URL], String) -> Void)?
    var finished: (() -> Void)?
    override var isFlipped: Bool { true }
    init(state: RadialState) {
        self.state = state
        super.init(frame: NSRect(x: 0, y: 0, width: RadialGeometry.size, height: RadialGeometry.size))
        registerForDraggedTypes([.fileURL])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    private func selection(_ sender: NSDraggingInfo) -> String? {
        guard !state.inspecting else { return nil }
        let point = convert(sender.draggingLocation, from: nil)
        guard let format = RadialGeometry.format(at: point), state.available.contains(format) else { return nil }
        return format
    }
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        state.highlighted = selection(sender)
        // Keep tracking when the cursor first enters through the neutral center.
        return .copy
    }
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        state.highlighted = selection(sender)
        return state.highlighted == nil ? [] : .copy
    }
    override func draggingExited(_ sender: NSDraggingInfo?) { state.highlighted = nil }
    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool { selection(sender) != nil }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let format = selection(sender),
              let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self],
                  options: [.urlReadingFileURLsOnly: true]) as? [URL],
              urls == expectedURLs, !urls.isEmpty else { return false }
        receive?(urls, format)
        return true
    }
    override func draggingEnded(_ sender: NSDraggingInfo) { finished?() }
}

private final class RadialPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class RadialController {
    let state: RadialState
    private let panel: RadialPanel
    private let dropView: RadialDropView
    var onDrop: (([URL], String) -> Void)?
    var onEnd: (() -> Void)?
    var isVisible: Bool { panel.isVisible }

    init() {
        let state = RadialState()
        self.state = state
        panel = RadialPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        dropView = RadialDropView(state: state)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .statusBar
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let hosting = NSHostingView(rootView: RadialMenuView(state: state))
        hosting.frame = dropView.bounds
        hosting.autoresizingMask = [.width, .height]
        dropView.addSubview(hosting)
        panel.contentView = dropView
        dropView.receive = { [weak self] urls, format in
            self?.hide()
            self?.onDrop?(urls, format)
        }
        dropView.finished = { [weak self] in self?.onEnd?() }
    }
    func show(at point: NSPoint, screen: NSScreen, urls: [URL], formats: [String]?, note: String) {
        let size = RadialGeometry.size
        let area = screen.visibleFrame
        let x = max(area.minX, min(point.x - size / 2, area.maxX - size))
        let y = max(area.minY, min(point.y - size / 2, area.maxY - size))
        dropView.expectedURLs = urls
        state.filename = urls.first?.lastPathComponent ?? ""
        state.fileCount = urls.count
        state.highlighted = nil
        update(formats: formats, note: note)
        panel.setFrame(NSRect(x: x, y: y, width: size, height: size), display: true)
        panel.orderFrontRegardless()
    }
    func update(formats: [String]?, note: String) {
        state.available = formats ?? []
        state.inspecting = formats == nil
        state.note = note
        if let selected = state.highlighted, !state.available.contains(selected) { state.highlighted = nil }
    }
    func hide() {
        state.highlighted = nil
        panel.orderOut(nil)
    }
}
