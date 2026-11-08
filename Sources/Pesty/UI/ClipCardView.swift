import AppKit
import ImageIO
import SwiftUI

struct ClipCardView: View {
    let item: ClipItem
    let index: Int
    let selected: Bool

    @State private var hovering = false
    @State private var preview: NSImage?
    @State private var previewFailed = false
    @State private var fileInfo: ClipPreviewProvider.FileInfo?
    private var store: ClipboardStore { ClipboardStore.shared }
    private var settings: Settings { Settings.shared }
    private var headerColor: Color { SourceColor.color(for: item.sourceBundleID) }

    var body: some View {
        VStack(spacing: 0) {
            header
            body_
        }
        .frame(width: Theme.cardWidth)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous))
        .background {
            if selected {
                RoundedRectangle(
                    cornerRadius: Theme.cardCorner + Theme.selectedCardRing,
                    style: .continuous
                )
                .fill(Theme.selection)
                .padding(-Theme.selectedCardRing)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous)
                .strokeBorder(selected ? Theme.selection : Theme.cardBorder,
                              lineWidth: selected ? 1.5 : 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 5, y: 2)
        .scaleEffect(hovering && !selected ? 1.015 : 1.0)
        .zIndex(selected ? 1 : 0)
        .animation(.spring(response: 0.32, dampingFraction: 0.72), value: selected)
        .animation(.easeOut(duration: 0.14), value: hovering)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture(count: 2) { AppController.shared.pasteItem(item) }
        .onTapGesture { store.select(item.id) }
        .highPriorityGesture(TapGesture().modifiers(.shift).onEnded { store.extendSelection(to: item.id) })
        .highPriorityGesture(TapGesture().modifiers(.command).onEnded { store.toggleSelection(item.id) })
        .onDrag { ClipDragProvider.make(for: item) }
        .contextMenu { menu }
        .task(id: item.id) { await loadPreview() }
    }

    private var header: some View {
        ZStack {
            headerColor
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(cardTypeLabel)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.headerText)
                    Text(item.createdAt.clipRelativeLong)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.headerSubText)
                }
                .lineLimit(1)
                // Same 14 pt from the left edge and the top edge.
                .padding(.top, 6)
                Spacer(minLength: 4)
                appIconTile
            }
            .padding(.leading, Theme.footerInset)
            .padding(.trailing, 12)
            .padding(.vertical, 8)
        }
        .frame(height: Theme.headerHeight)
    }

    private var cardTypeLabel: String {
        if item.type == .file, item.fileURLs.count > 1 { return L("%d files", item.fileURLs.count) }
        return item.type.label
    }

    private var appIconTile: some View {
        // The tile's corner matches the card's, and only two points of the
        // tile stay visible around the icon: less padding, bigger icon.
        RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous)
            .fill(Color.white.opacity(0.10))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.10))
            )
            .frame(width: Theme.appIconTileSize, height: Theme.appIconTileSize)
            .overlay(
                Image(nsImage: AppIconProvider.icon(
                    forBundleID: item.sourceBundleID,
                    pointSize: Theme.appIconSize,
                    scale: NSScreen.main?.backingScaleFactor ?? 2))
                    .resizable()
                    .interpolation(.none)
                    .frame(width: Theme.appIconSize, height: Theme.appIconSize)
            )
    }

    private var body_: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.horizontal, showsImage ? 0 : Theme.footerInset)
                .padding(.top, showsImage ? 0 : 11)
            footer
                .padding(.horizontal, Theme.footerInset)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.cardBody)
    }

    private var showsImage: Bool {
        ClipPreviewProvider.showsImage(item) && !previewFailed
    }

    @ViewBuilder
    private var content: some View {
        switch item.type {
        case .image:
            imageCanvas
        case .color:
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(Color(hex: item.colorHex ?? "#000") ?? .black)
                Text(item.colorHex ?? "")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white).shadow(radius: 1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .file:
            if showsImage {
                imageCanvas
            } else {
                fileContent
            }
        case .link:
            VStack(spacing: 10) {
                Spacer(minLength: 0)
                Image(systemName: "safari").font(.system(size: 34, weight: .light))
                    .foregroundStyle(Theme.cardTextTertiary)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
        default:
            Text(item.text ?? "")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.cardTextPrimary.opacity(0.9))
                .lineLimit(10)
                .multilineTextAlignment(.leading)
        }
    }

    private var imageCanvas: some View {
        ZStack {
            Theme.imagePlate
            if let image = preview ?? ClipPreviewProvider.cachedImage(for: item) {
                Image(nsImage: image)
                    .resizable().interpolation(.medium).scaledToFit()
            } else {
                placeholder("photo")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    @ViewBuilder
    private var fileContent: some View {
        VStack(spacing: 9) {
            if let icon = fileInfo?.icon ?? ClipPreviewProvider.cachedIcon(for: item) {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: Theme.fileIconSize, height: Theme.fileIconSize)
                    .opacity(fileInfo?.isMissing == true ? 0.5 : 1)
            } else {
                Image(systemName: "doc.fill").font(.system(size: 32))
                    .foregroundStyle(headerColor)
            }
            Text(item.displayTitle).font(.system(size: 12))
                .foregroundStyle(Theme.cardTextSecondary).lineLimit(2)
                .multilineTextAlignment(.center)
            if fileInfo?.isMissing == true {
                Text("File not found".localized)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.cardTextTertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func loadPreview() async {
        preview = ClipPreviewProvider.cachedImage(for: item)
        fileInfo = nil
        previewFailed = false
        if ClipPreviewProvider.showsImage(item) {
            if preview == nil {
                preview = await ClipPreviewProvider.image(for: item, scale: NSScreen.main?.backingScaleFactor ?? 2)
            }
            guard preview == nil, item.type == .file else { return }
            previewFailed = true
        }
        guard item.type == .file else { return }
        fileInfo = await ClipPreviewProvider.fileInfo(for: item)
    }

    private func placeholder(_ symbol: String) -> some View {
        Image(systemName: symbol).font(.system(size: 30))
            .foregroundStyle(Theme.cardTextTertiary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 3) {
            if item.type == .link {
                Text(item.displayTitle)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Theme.cardTextPrimary).lineLimit(1)
            }
            footerLine
                .frame(minHeight: item.type == .link ? 17 : Theme.footerHeight)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var footerLine: some View {
        HStack(alignment: .center, spacing: 6) {
            Text(metaLeft)
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.cardTextSecondary)
                .lineLimit(item.type == .file ? 3 : 1)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            if index < 9 {
                HStack(spacing: 3) {
                    Text(settings.quickPasteModifierDisplay)
                        .font(.system(size: 10.5, weight: .semibold))
                    Text("\(index + 1)")
                        .font(.system(size: 10.5, weight: .semibold))
                }
                .foregroundStyle(Theme.cardTextTertiary)
            }
        }
    }

    private var isSingleImageFile: Bool {
        ClipPreviewProvider.imageFileURL(for: item) != nil
    }

    private static let homePath: String = {
        if let home = getpwuid(getuid())?.pointee.pw_dir { return String(cString: home) }
        return NSHomeDirectory()
    }()

    private static func abbreviatedPath(_ path: String) -> String {
        if path == homePath { return "~" }
        guard path.hasPrefix(homePath + "/") else { return path }
        return "~" + path.dropFirst(homePath.count)
    }

    private var metaLeft: String {
        switch item.type {
        case .text, .richText:
            return L("%d characters", item.charCount)
        case .link:
            return (item.text ?? "").replacingOccurrences(of: "https://", with: "")
                                    .replacingOccurrences(of: "http://", with: "")
        case .file:
            guard item.fileURLs.count == 1,
                  let url = item.fileURLs.first.flatMap(URL.init(string:)) else {
                return item.fileURLs
                    .compactMap { URL(string: $0)?.lastPathComponent }
                    .joined(separator: ", ")
            }
            if isSingleImageFile {
                guard let size = ImagePixelSize.of(url) else { return url.lastPathComponent }
                return "\(Int(size.width)) × \(Int(size.height))"
            }
            return Self.abbreviatedPath(url.path)
        case .image:
            guard let size = ImagePixelSize.of(item) else { return "Image".localized }
            return "\(Int(size.width)) × \(Int(size.height))"
        case .color:
            return item.colorHex ?? "Color".localized
        }
    }

    @ViewBuilder
    private var menu: some View {
        Button { AppController.shared.pasteItem(item) } label: {
            Label(AppController.shared.pasteMenuTitle, systemImage: "doc.on.clipboard")
        }

        Button { AppController.shared.pasteItem(item, format: .plainText) } label: {
            Label("Paste as Plain Text".localized, systemImage: "text.alignleft")
        }
        .disabled(item.plainText == nil)

        Button { AppController.shared.pasteItem(item, format: .cleanFormatting) } label: {
            Label("Paste with Clean Formatting".localized, systemImage: "paintbrush")
        }
        .disabled(!FormatConverter.canConvert(item))

        Button { AppController.shared.pasteItem(item, format: .markdown) } label: {
            Label("Paste as Markdown".localized, systemImage: "number")
        }
        .disabled(!FormatConverter.canConvert(item))

        Button { AppController.shared.copyItem(item) } label: {
            Label("Copy".localized, systemImage: "doc.on.doc")
        }

        Divider()

        Button { AppController.shared.editItem(item) } label: {
            Label("Edit".localized, systemImage: "pencil")
        }
        .disabled(!isEditable)

        if writingToolsAvailable {
            Button { AppController.shared.editItem(item, launchWritingTools: true) } label: {
                Label("Writing Tools".localized, systemImage: "pencil.and.scribble")
            }
        }

        Button { renameItem() } label: {
            Label("Rename…".localized, systemImage: "pencil.line")
        }

        Divider()

        Menu {
            if store.pinboards.isEmpty {
                Button("No Pinboards Yet".localized) {}
                    .disabled(true)
            } else {
                ForEach(store.pinboards) { b in
                    Button { store.saveToPinboard(item, boardID: b.id) } label: {
                        Label {
                            Text(b.name)
                        } icon: {
                            Image(nsImage: Self.pinboardMenuIcon(color: NSColor(b.color)))
                                .renderingMode(.original)
                        }
                    }
                }
            }
            Divider()
            Button { pinToNewBoard() } label: {
                Label("Create Pinboard…".localized, systemImage: "plus")
            }
        } label: {
            Label("Pin".localized, systemImage: "pin")
        }

        Divider()

        Button { AppController.shared.showPreview(for: item) } label: {
            Label("Preview".localized, systemImage: "eye")
        }

        Button { AppController.shared.showSharePicker(for: item) } label: {
            Label("Share".localized, systemImage: "square.and.arrow.up")
        }

        Divider()

        Button(role: .destructive) {
            AppController.shared.deleteSelection(containing: item)
        } label: {
            Label(deleteMenuTitle, systemImage: "trash")
        }
    }

    private var deleteMenuTitle: String {
        let count = store.multiSelectedIDs.contains(item.id) ? store.multiSelectedIDs.count : 1
        return count > 1 ? L("Delete %d Clips", count) : "Delete".localized
    }

    private var isEditable: Bool {
        [.text, .richText, .link, .color].contains(item.type)
    }

    private var writingToolsAvailable: Bool {
        guard [.text, .richText, .link].contains(item.type) else { return false }
        guard #available(macOS 15.2, *) else { return false }
        return NSWritingToolsCoordinator.isWritingToolsAvailable
    }

    private func renameItem() {
        if let title = TextPrompt.run(title: "Rename".localized, message: "Card title".localized,
                                      defaultValue: item.customTitle ?? "") {
            store.setTitle(title, for: item)
        }
    }

    private func pinToNewBoard() {
        if let name = TextPrompt.run(title: "Create Pinboard".localized, message: "Name".localized) {
            let board = store.addPinboard(name: name)
            store.saveToPinboard(item, boardID: board.id)
        }
    }

    private static func pinboardMenuIcon(color: NSColor) -> NSImage {
        let size = NSSize(width: 12, height: 12)
        let image = NSImage(size: size, flipped: false) { rect in
            color.setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1)).fill()
            return true
        }
        image.isTemplate = false
        return image
    }
}

@MainActor
enum ImagePixelSize {
    private static var cache: [String: CGSize?] = [:]
    private static let cacheLimit = 512

    static func of(_ item: ClipItem) -> CGSize? {
        guard item.imageFileName != nil,
              let url = ClipboardStore.shared.imageURL(for: item) else { return nil }
        return of(url)
    }

    static func of(_ url: URL) -> CGSize? {
        let name = url.path
        if let cached = cache[name] { return cached }
        if cache.count >= cacheLimit { cache.removeAll() }
        let size = read(url)
        cache.updateValue(size, forKey: name)
        return size
    }

    private static func read(_ url: URL) -> CGSize? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else { return nil }
        return CGSize(width: width, height: height)
    }
}
