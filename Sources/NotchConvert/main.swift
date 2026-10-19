import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct WorkerReply: Decodable {
    struct FileInfo: Decodable { let name: String; let kind: String; let note: String }
    let ok: Bool
    let formats: [String]?
    let files: [FileInfo]?
    let outputs: [String]?
    let folder: String?
    let error: String?
}

final class ConverterModel: ObservableObject {
    @Published var files: [URL] = []
    @Published var formats: [String] = []
    @Published var selected = "pdf"
    @Published var message = "Keynote 또는 PowerPoint 파일을 추가해 주세요."
    @Published var busy = false
    @Published var result: URL?
    @Published var outputs: [URL] = []
    @Published var failed = false
    @Published var inspecting = false
    @Published var destination = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
    var expand: (() -> Void)?

    func chooseFiles() {
        guard !busy else { return }
        let dialog = NSOpenPanel()
        dialog.allowsMultipleSelection = true
        dialog.canChooseDirectories = false
        dialog.treatsFilePackagesAsDirectories = false
        dialog.allowedContentTypes = ["key", "ppt", "pptx"].compactMap { UTType(filenameExtension: $0) }
        if dialog.runModal() == .OK { accept(dialog.urls) }
    }

    func chooseDestination() {
        guard !busy else { return }
        let dialog = NSOpenPanel()
        dialog.canChooseFiles = false
        dialog.canChooseDirectories = true
        dialog.canCreateDirectories = true
        if dialog.runModal() == .OK, let url = dialog.url { destination = url }
    }

    func accept(_ urls: [URL], convertingTo format: String? = nil) {
        guard !busy, !urls.isEmpty else { return }
        files = urls
        formats = []
        result = nil
        outputs = []
        inspecting = true
        message = "파일을 확인하고 있습니다…"
        expand?()
        run(["inspect"] + urls.map(\.path)) { reply in
            self.formats = reply.formats ?? []
            if !self.formats.contains(self.selected) { self.selected = self.formats.first ?? "zip" }
            let notes = Array(Set((reply.files ?? []).map(\.note).filter { !$0.isEmpty })).sorted()
            self.message = notes.isEmpty ? "\(urls.count)개 파일 · 출력 형식을 선택해 주세요." : notes.joined(separator: "\n")
            if let format = format {
                guard self.formats.contains(format) else {
                    self.failed = true
                    self.message = "선택한 형식으로 변환할 수 없습니다. Keynote 설치 상태를 확인해 주세요."
                    return
                }
                self.selected = format
                self.destination = urls[0].deletingLastPathComponent()
                self.beginConversion(besideOriginal: true)
            }
        }
    }

    func convert() { beginConversion(besideOriginal: false) }

    private func beginConversion(besideOriginal: Bool) {
        guard !busy, formats.contains(selected) else { return }
        inspecting = false
        result = nil
        outputs = []
        message = "변환 중입니다… 원본 파일은 보존됩니다."
        let arguments = besideOriginal
            ? ["convert", "--format", selected, "--beside-original"]
            : ["convert", "--format", selected, "--output", destination.path]
        run(arguments + files.map(\.path)) { reply in
            self.outputs = (reply.outputs ?? []).map { URL(fileURLWithPath: $0) }
            self.result = reply.folder.map { URL(fileURLWithPath: $0) }
            self.message = besideOriginal ? "변환이 완료되었습니다. 원본 옆에 저장했어요." : "변환이 완료되었습니다."
        }
    }

    func select(_ format: String) {
        guard !busy else { return }
        selected = format
        result = nil
        outputs = []
        failed = false
        message = "출력 형식을 선택한 뒤 변환해 주세요."
    }

    func reset() {
        guard !busy else { return }
        files = []
        formats = []
        outputs = []
        result = nil
        failed = false
        message = "Keynote 또는 PowerPoint 파일을 추가해 주세요."
    }

    private func run(_ arguments: [String], completion: @escaping (WorkerReply) -> Void) {
        busy = true
        failed = false
        WorkerClient.request(arguments) { result in
            self.busy = false
            switch result {
            case .success(let reply):
                if reply.ok { completion(reply) }
                else {
                    self.failed = true
                    self.message = reply.error ?? "변환하지 못했습니다."
                }
            case .failure(let error):
                self.failed = true
                self.message = error.localizedDescription
            }
        }
    }
}

// Explicit grayscale styling keeps system accent colors out of the interface.
struct MonoButton: ButtonStyle {
    var prominent = false
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 14).padding(.vertical, 10)
            .foregroundStyle(prominent ? Color.black : Color.white.opacity(0.86))
            .background(prominent ? Color.white : Color.white.opacity(configuration.isPressed ? 0.16 : 0.07),
                        in: RoundedRectangle(cornerRadius: 10))
            .opacity(enabled ? (configuration.isPressed ? 0.75 : 1) : 0.3)
    }
}

struct ConverterView: View {
    @ObservedObject var model: ConverterModel
    var topInset: CGFloat
    var collapse: () -> Void

    private var title: String {
        if model.busy { return model.inspecting ? "파일 확인 중" : "변환하고 있어요" }
        if model.failed { return "다시 확인해 주세요" }
        if model.result != nil { return "변환 완료" }
        return model.files.isEmpty ? "파일을 여기에 놓으세요" : "어떤 형식으로 바꿀까요?"
    }

    private var formatNote: String {
        switch model.selected {
        case "jpeg", "png": return "슬라이드마다 한 장의 이미지로 저장합니다."
        case "pptx": return "PowerPoint(.pptx) 파일로 내보냅니다."
        case "zip": return "선택한 원본 파일을 하나로 압축합니다."
        default: return "파일마다 별도의 PDF로 저장합니다."
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.down.doc").font(.system(size: 14))
                Text("NotchConvert").font(.system(size: 13, weight: .semibold))
                Spacer()
                Button(action: collapse) {
                    Image(systemName: "minus").frame(width: 28, height: 28)
                }.buttonStyle(.plain).foregroundStyle(Color.white.opacity(0.55))
                    .help("접기").accessibilityLabel("변환 창 접기")
            }
            VStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(Color.white.opacity(0.16), lineWidth: 1).frame(width: 52, height: 58)
                    if model.busy {
                        ProgressView().controlSize(.small).tint(.white)
                    } else {
                        Image(systemName: model.failed ? "exclamationmark" :
                                (model.result == nil ? "arrow.down" : "checkmark"))
                            .font(.system(size: 22, weight: .light))
                    }
                }
                Text(title).font(.system(size: 21, weight: .medium))
                if model.files.isEmpty {
                    Text("Keynote .key · PowerPoint .ppt / .pptx")
                        .font(.system(size: 12)).foregroundStyle(Color.white.opacity(0.52))
                } else {
                    Text(model.files.count == 1 ? model.files[0].lastPathComponent :
                            "\(model.files[0].lastPathComponent) 외 \(model.files.count - 1)개")
                        .font(.system(size: 12)).foregroundStyle(Color.white.opacity(0.52))
                        .lineLimit(1).truncationMode(.middle)
                        .help(model.files.map(\.lastPathComponent).joined(separator: "\n"))
                }
                if model.files.isEmpty {
                    Button("파일 선택", action: model.chooseFiles).buttonStyle(MonoButton())
                }
            }
            .frame(maxWidth: .infinity).padding(.vertical, model.files.isEmpty ? 18 : 4)

            if !model.formats.isEmpty && model.result == nil {
                VStack(alignment: .leading, spacing: 10) {
                    Text("출력 형식").font(.system(size: 11)).foregroundStyle(Color.white.opacity(0.5))
                    HStack(spacing: 6) {
                        ForEach(model.formats, id: \.self) { format in
                            Button { model.select(format) } label: {
                                Text(format.uppercased()).font(.system(size: 11, weight: .semibold))
                                    .frame(maxWidth: .infinity).padding(.vertical, 11)
                                    .foregroundStyle(model.selected == format ? Color.black : Color.white.opacity(0.65))
                                    .background(model.selected == format ? Color.white : Color.white.opacity(0.06),
                                                in: RoundedRectangle(cornerRadius: 9))
                            }
                            .buttonStyle(.plain).disabled(model.busy)
                            .accessibilityLabel("\(format.uppercased()) 출력")
                            .accessibilityAddTraits(model.selected == format ? .isSelected : [])
                        }
                    }
                    Text(formatNote).font(.system(size: 11)).foregroundStyle(Color.white.opacity(0.5))
                }
            }
            if model.result != nil {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(model.outputs, id: \.self) { url in
                            HStack(spacing: 9) {
                                Image(systemName: "doc")
                                Text(url.lastPathComponent).lineLimit(1).truncationMode(.middle)
                                Spacer(minLength: 0)
                                Image(systemName: "arrow.up.right").foregroundStyle(Color.white.opacity(0.4))
                            }
                            .font(.system(size: 12)).padding(10)
                            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                            .onDrag { NSItemProvider(contentsOf: url) ?? NSItemProvider() }
                            .help("다른 앱이나 Finder로 드래그하세요")
                        }
                    }
                }.frame(maxHeight: 90)
            }
            ScrollView {
                Text(model.message).font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(model.failed ? 0.9 : 0.5))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }.frame(maxHeight: 42)
            Spacer(minLength: 0)
            Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1)
            HStack {
                Button(action: model.chooseDestination) {
                    Label(model.destination.lastPathComponent, systemImage: "folder")
                        .font(.system(size: 11)).lineLimit(1).truncationMode(.middle)
                }.buttonStyle(.plain).foregroundStyle(Color.white.opacity(0.55))
                    .help("저장 위치: \(model.destination.path)").disabled(model.busy)
                Spacer()
                if let result = model.result {
                    Button("새 변환", action: model.reset).buttonStyle(MonoButton())
                    Button("Finder에서 보기") {
                        if model.outputs.isEmpty { NSWorkspace.shared.open(result) }
                        else { NSWorkspace.shared.activateFileViewerSelecting(model.outputs) }
                    }
                        .buttonStyle(MonoButton(prominent: true))
                } else if !model.files.isEmpty {
                    Button("파일 변경", action: model.chooseFiles).buttonStyle(MonoButton()).disabled(model.busy)
                    Button("변환", action: model.convert).buttonStyle(MonoButton(prominent: true))
                        .disabled(model.busy || model.formats.isEmpty)
                }
            }
        }
        .padding(24).padding(.top, topInset)
        .frame(width: 440, height: 470 + topInset, alignment: .top)
        .foregroundStyle(Color.white)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
        .tint(.white).preferredColorScheme(.dark)
    }
}

final class DropHost: NSView {
    var received: (([URL]) -> Void)?
    var entered: (() -> Void)?
    var canAccept: (() -> Bool)?
    override init(frame: NSRect) {
        super.init(frame: frame)
        registerForDraggedTypes([.fileURL])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard canAccept?() != false else { return [] }
        entered?()
        return .copy
    }
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        canAccept?() == false ? [] : .copy
    }
    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool { canAccept?() != false }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard canAccept?() != false,
              let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self],
                  options: [.urlReadingFileURLsOnly: true]) as? [URL], !urls.isEmpty else { return false }
        received?(urls)
        return true
    }
}

final class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = ConverterModel()
    var panel: NotchPanel!
    var status: NSStatusItem!
    var poll: Timer?
    var expanded = false
    var dragScreen: NSScreen?
    var lastDragChange = -1
    var wasDragging = false
    var dropHost: DropHost?
    let radial = RadialController()
    var dragURLs: [URL] = []
    var dragFormats: [String]?
    var dragNote = ""
    var dragInspectionID: UUID?
    var dragSuppressed = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        status.button?.image = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: "NotchConvert")
        let menu = NSMenu()
        menu.addItem(withTitle: "변환 창 열기", action: #selector(openPanel), keyEquivalent: "o").target = self
        menu.addItem(withTitle: "종료", action: #selector(quit), keyEquivalent: "q").target = self
        status.menu = menu
        panel = NotchPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .statusBar
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        model.expand = { [weak self] in self?.show(expanded: true) }
        radial.onDrop = { [weak self] urls, format in
            guard let self = self, !self.model.busy else { return }
            self.dragSuppressed = true
            self.model.accept(urls, convertingTo: format)
        }
        radial.onEnd = { [weak self] in
            self?.radial.hide()
            self?.dragSuppressed = true
        }
        // Query only public drag pasteboard, pointer/button and current modifier state.
        // Common run-loop modes keep polling active during AppKit's drag tracking.
        lastDragChange = NSPasteboard(name: .drag).changeCount
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in self?.checkDrag() }
        poll = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func screenAtPointer() -> NSScreen? {
        NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
    }

    func checkDrag() {
        let down = NSEvent.pressedMouseButtons & 1 != 0
        let board = NSPasteboard(name: .drag)
        if !down {
            if wasDragging {
                // Let AppKit deliver the final drop before dismissing the destination.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                    guard let self = self, !self.wasDragging else { return }
                    self.radial.hide()
                }
            }
            wasDragging = false
            dragURLs = []
            dragFormats = nil
            dragInspectionID = nil
            dragSuppressed = false
            lastDragChange = board.changeCount
            return
        }
        let shiftHeld = NSEvent.modifierFlags.contains(.shift)
        if board.changeCount != lastDragChange {
            lastDragChange = board.changeCount
            if let urls = board.readObjects(forClasses: [NSURL.self],
                options: [.urlReadingFileURLsOnly: true]) as? [URL], !urls.isEmpty,
               urls.allSatisfy({ ["key", "ppt", "pptx"].contains($0.pathExtension.lowercased()) }) {
                if !wasDragging || urls != dragURLs { beginDragInspection(urls) }
            } else {
                wasDragging = false
                dragURLs = []
                dragInspectionID = nil
                radial.hide()
            }
        }
        guard wasDragging, !dragURLs.isEmpty, !dragSuppressed, !model.busy,
              let screen = screenAtPointer() else { return }
        if shiftHeld && !radial.isVisible {
            showDragMenu(at: NSEvent.mouseLocation, screen: screen)
        }
        // Once anchored, the menu stays still so the file can move into a sector.
        guard !radial.isVisible else { return }
        let point = NSEvent.mouseLocation
        if abs(point.x - screen.frame.midX) < 175 && point.y > screen.frame.maxY - 75 {
            showDragMenu(at: point, screen: screen)
        }
    }

    private func beginDragInspection(_ urls: [URL]) {
        wasDragging = true
        dragURLs = urls
        dragFormats = nil
        dragNote = ""
        dragSuppressed = false
        let generation = UUID()
        dragInspectionID = generation
        radial.update(formats: nil, note: "")
        WorkerClient.request(["inspect"] + urls.map(\.path)) { [weak self] result in
            guard let self = self, self.dragInspectionID == generation else { return }
            switch result {
            case .success(let reply):
                self.dragFormats = reply.ok ? (reply.formats ?? []) : []
                self.dragNote = reply.error ?? Array(Set((reply.files ?? []).map(\.note)
                    .filter { !$0.isEmpty })).sorted().joined(separator: "\n")
            case .failure(let error):
                self.dragFormats = []
                self.dragNote = error.localizedDescription
            }
            self.radial.update(formats: self.dragFormats, note: self.dragNote)
        }
    }

    private func showDragMenu(at point: NSPoint, screen: NSScreen) {
        panel.orderOut(nil)
        expanded = false
        dragScreen = screen
        radial.show(at: point, screen: screen, urls: dragURLs, formats: dragFormats, note: dragNote)
    }

    @objc func openPanel() {
        radial.hide()
        dragScreen = screenAtPointer()
        show(expanded: true)
    }

    func show(expanded: Bool) {
        self.expanded = expanded
        guard let screen = dragScreen ?? NSScreen.main else { return }
        let topInset = max(screen.safeAreaInsets.top, 12)
        let size = NSSize(width: expanded ? 440 : 300, height: expanded ? 470 + topInset : 76 + topInset)
        panel.setFrame(NSRect(x: screen.frame.midX - size.width / 2, y: screen.frame.maxY - size.height,
                              width: size.width, height: size.height), display: true)
        // Keep the registered drag destination alive while the panel expands.
        let host = dropHost ?? DropHost(frame: NSRect(origin: .zero, size: size))
        dropHost = host
        host.frame = NSRect(origin: .zero, size: size)
        host.subviews.forEach { $0.removeFromSuperview() }
        host.canAccept = { [weak self] in self?.model.busy == false }
        host.received = { [weak self] urls in self?.model.accept(urls) }
        // Defer replacing the drag destination until AppKit finishes draggingEntered.
        host.entered = { [weak self] in
            guard let self = self, !self.expanded else { return }
            DispatchQueue.main.async { self.show(expanded: true) }
        }
        let content: NSView
        if expanded {
            content = NSHostingView(rootView: ConverterView(model: model, topInset: topInset, collapse: { [weak self] in
                self?.expanded = false
                self?.panel.orderOut(nil)
            }))
        } else {
            content = NSHostingView(rootView:
                Text("여기에 놓아 변환하기").font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white).padding(.top, topInset)
                    .frame(width: 300, height: 76 + topInset).background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 18)))
        }
        content.frame = host.bounds
        content.autoresizingMask = [.width, .height]
        host.addSubview(content)
        panel.contentView = host
        panel.orderFrontRegardless()
    }
    @objc func quit() { NSApp.terminate(nil) }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
