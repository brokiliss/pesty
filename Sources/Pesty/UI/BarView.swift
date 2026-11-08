import SwiftUI

struct BarView: View {
    let searchBridge: BarSearchFieldBridge
    @Bindable private var store = ClipboardStore.shared
    @Bindable private var settings = Settings.shared
    @State private var draftBarHeight: Double?

    private var searchIsActive: Bool {
        store.barInputMode == .search || !store.searchText.isEmpty
    }

    private var searchTextBinding: Binding<String> {
        Binding(
            get: { store.searchText },
            set: { AppController.shared.updateBarSearchText($0) }
        )
    }

    var body: some View {
        ZStack {
            panelBackground
        }
        .overlay(alignment: .top) {
            VStack(spacing: 0) {
                topBar
                strip
            }
        }
        .overlay(alignment: .top) {
            if settings.showBarResizeHandle {
                BarResizeHandle(
                    accessibilityValue: CGFloat(settings.barHeight),
                    onBegin: AppController.shared.beginBarResize,
                    onChange: AppController.shared.updateBarResize,
                    onEnd: AppController.shared.endBarResize,
                    onCancel: AppController.shared.cancelBarResize,
                    onAccessibilityAdjustment: AppController.shared.adjustBarHeight)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.10))
        )
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var panelBackground: some View {
        if #available(macOS 26.0, *) {
            Color.clear
        } else {
            VisualEffectView(material: .hudWindow)
            Theme.panelTint
        }
    }

    private var topBar: some View {
        GeometryReader { proxy in
            HStack(spacing: 14) {
                #if MAS
                if settings.cloudKitSync { syncButton }
                #else
                if settings.iCloudSync { syncButton }
                #endif
                searchIndicator
                // Capped so the controls stay reachable: an uncapped tab strip
                // would claim the middle of the bar and sit under them.
                PinboardTabs()
                    .frame(maxWidth: max(160, min(430, proxy.size.width * 0.2)),
                           alignment: .leading)
                Spacer(minLength: 10)
                panelControls
                    .padding(.trailing, 2)
                if store.multiSelectedIDs.count > 1 {
                    bulkDeleteButton
                }
                if store.hasUndoableDeletion {
                    undoButton
                }
                moreMenu
            }
            .padding(.horizontal, 18)
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .frame(height: 56)
        .onChange(of: store.barPresentationToken) { _, _ in
            // A drag interrupted by hiding the bar must not leave a stale
            // reading behind for the next presentation.
            draftBarHeight = nil
        }
    }

    private var syncButton: some View {
        Button {
            AppController.shared.toggleICloudSync()
        } label: {
            Image(systemName: settings.iCloudSync ? "checkmark.icloud.fill" : "arrow.triangle.2.circlepath")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(settings.iCloudSync ? Theme.selection : Theme.chromeTextSecondary)
        }
        .buttonStyle(.plain)
        .help(settings.iCloudSync ? "iCloud sync on".localized : "Turn on iCloud sync".localized)
    }

    private var searchIndicator: some View {
        HStack(spacing: searchIsActive ? 6 : 0) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(searchIsActive ? Theme.chromeTextPrimary : Theme.chromeTextSecondary)
                .accessibilityHidden(true)

            NativeBarSearchField(
                text: searchTextBinding,
                placeholder: "Search".localized,
                bridge: searchBridge,
                onBegin: { AppController.shared.setBarSearchEditing(true) },
                onEnd: { AppController.shared.setBarSearchEditing(false) },
                onSubmit: { AppController.shared.pasteSelected() },
                onCancel: { AppController.shared.cancelBarSearchOrHide() },
                onMoveSelection: { store.moveSelection(by: $0) }
            )
            .frame(minWidth: searchIsActive ? 120 : 0,
                   idealWidth: searchIsActive ? 180 : 0,
                   maxWidth: searchIsActive ? 260 : 0,
                   alignment: .leading)
            .opacity(searchIsActive ? 1 : 0)
            .allowsHitTesting(searchIsActive)
            .accessibilityHidden(!searchIsActive)

            if searchIsActive {
                Button {
                    AppController.shared.clearBarSearch()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12)).foregroundStyle(Theme.chromeTextTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search".localized)
            }
        }
        .padding(.horizontal, searchIsActive ? 10 : 0)
        .frame(height: 30)
        .background(searchIsActive ? Theme.fieldBG : Color.clear, in: Capsule())
        .layoutPriority(searchIsActive ? 2 : 0)
        .animation(.easeOut(duration: 0.15), value: searchIsActive)
    }

    /// Panel height and the resize-handle switch live in the empty part of the
    /// top bar instead of a submenu. The slider only writes the new height when
    /// the drag ends, so the panel does not chase the pointer.
    private var panelControls: some View {
        HStack(spacing: 9) {
            Slider(
                value: Binding(get: { draftBarHeight ?? settings.barHeight },
                               set: { draftBarHeight = $0 }),
                in: BarResizeGeometry.minimumHeight...BarResizeGeometry.maximumHeight
            ) { editing in
                if editing {
                    draftBarHeight = settings.barHeight
                } else if let draft = draftBarHeight {
                    // The track is continuous, so the stored height is rounded
                    // once on release instead of snapping under the pointer.
                    AppController.shared.setBarHeight(draft.rounded())
                    draftBarHeight = nil
                }
            }
            .frame(width: 106)
            .controlSize(.small)
            .help("Bar height".localized)
            .accessibilityLabel("Bar height".localized)
            .accessibilityValue(L("%d pt", Int((draftBarHeight ?? settings.barHeight).rounded())))

            Text("\(Int((draftBarHeight ?? settings.barHeight).rounded()))")
                .font(.system(size: 10.5, weight: .medium).monospacedDigit())
                .foregroundStyle(Theme.chromeTextSecondary)
                .frame(width: 24, alignment: .trailing)

            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 1, height: 14)

            Button {
                settings.showBarResizeHandle.toggle()
            } label: {
                Image(systemName: settings.showBarResizeHandle
                      ? "arrow.up.and.down.square.fill"
                      : "arrow.up.and.down.square")
                    .font(.system(size: 13))
                    .foregroundStyle(settings.showBarResizeHandle
                                     ? Theme.selection : Theme.chromeTextTertiary)
                    .frame(width: 18)
            }
            .buttonStyle(.plain)
            .help("Show resize handle on the Paste Bar".localized)
            .accessibilityLabel("Show resize handle on the Paste Bar".localized)
        }
        .padding(.horizontal, 11)
        .frame(height: 30)
        .background(Theme.fieldBG, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.07)))
    }

    private var bulkDeleteButton: some View {
        let count = store.multiSelectedIDs.count
        return Button(role: .destructive) {
            AppController.shared.deleteEffectiveSelection()
        } label: {
            Label(L("Delete %d", count), systemImage: "trash")
                .font(.system(size: 12.5, weight: .medium))
                .lineLimit(1)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .fixedSize()
        .help(L("Delete %d selected clips (⌘⌫)", count))
        .accessibilityLabel(L("Delete %d selected clips", count))
    }

    private var undoButton: some View {
        Button {
            store.undoLastDelete()
        } label: {
            Label("Undo".localized, systemImage: "arrow.uturn.backward")
                .font(.system(size: 12.5, weight: .medium))
                .lineLimit(1)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .fixedSize()
        .help("Undo the last deletion (⌘Z), available for 5 minutes".localized)
        .accessibilityLabel("Undo last deletion".localized)
    }

    private var moreMenu: some View {
        Menu {
            Button { AppController.shared.showSettings() } label: {
                Label("Settings…".localized, systemImage: "gearshape")
            }
            Button { store.clearHistory() } label: {
                Label("Clear History".localized, systemImage: "trash")
            }
            Divider()
            Button { AppController.shared.showAbout() } label: {
                Label("About Pesty".localized, systemImage: "info.circle")
            }
            Button { NSApp.terminate(nil) } label: {
                Label("Quit Pesty".localized, systemImage: "power")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.chromeTextSecondary)
                .frame(width: 30, height: 30)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 34)
        .fixedSize()
    }

    private static let stripStartID = "stripStart"

    private var strip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: Theme.cardSpacing) {
                    ForEach(Array(store.visibleItems.enumerated()), id: \.element.id) { index, item in
                        ClipCardView(item: item,
                                     index: index,
                                     selected: store.isSelected(item.id))
                            .id(item.id)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.92).combined(with: .opacity),
                                removal: .opacity))
                    }
                }
                .padding(.horizontal, Theme.cardStripHorizontalPadding)
                .padding(.top, 16)
                .padding(.bottom, 26)
                .animation(.spring(response: 0.34, dampingFraction: 0.8), value: store.visibleItems.count)
                .id(Self.stripStartID)
            }
            .onChange(of: store.barPresentationToken) { _, _ in
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    proxy.scrollTo(Self.stripStartID, anchor: .leading)
                }
            }
            .onChange(of: store.selectedID) { _, id in
                guard let id else { return }
                scrollToSelected(id, proxy: proxy)
            }
            .onChange(of: settings.selectedClipPosition) { _, _ in
                guard let id = store.selectedID else { return }
                scrollToSelected(id, proxy: proxy)
            }
            .overlay { if store.visibleItems.isEmpty { emptyState } }
        }
        .frame(maxHeight: .infinity)
    }

    private func scrollToSelected(_ id: UUID, proxy: ScrollViewProxy) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
            proxy.scrollTo(id, anchor: settings.selectedClipPosition == .rightEdge ? .trailing : .center)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: store.searchText.isEmpty ? "doc.on.clipboard" : "magnifyingglass")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(Theme.chromeTextTertiary)
            Text(store.searchText.isEmpty
                 ? "Nothing copied yet".localized
                 : L("No matches for \u{201C}%@\u{201D}", store.searchText))
                .font(.system(size: 13))
                .foregroundStyle(Theme.chromeTextSecondary)
        }
    }
}
