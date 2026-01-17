import SwiftUI

struct WindowAccessor: NSViewRepresentable {
    let onResolve: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = WindowResolverView()
        view.onResolve = onResolve
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let window = nsView.window {
            onResolve(window)
        }
    }
}

final class WindowResolverView: NSView {
    var onResolve: ((NSWindow) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let window {
            onResolve?(window)
        }
    }
}

struct ContentView: View {
    @StateObject private var documentState: DocumentState
    @State private var isHoveringEdge = false
    @State private var isHoveringSidebar = false
    @State private var isOutlinePinned = false
    @State private var scrollRequest: ScrollRequest?
    @State private var commentSelectionRequest: UUID?

    init(documentState: DocumentState = DocumentState()) {
        _documentState = StateObject(wrappedValue: documentState)
    }

    private var canShowOutline: Bool {
        !documentState.htmlContent.isEmpty
    }

    private var canShowComments: Bool {
        !documentState.htmlContent.isEmpty
    }

    private var showOutline: Bool {
        guard canShowOutline else { return false }
        return isOutlinePinned || isHoveringEdge || isHoveringSidebar
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if documentState.htmlContent.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("Open a Markdown file")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text("Use File > Open or press \u{2318}O")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    WebView(
                        htmlContent: documentState.htmlContent,
                        scrollRequest: scrollRequest,
                        reloadToken: documentState.reloadToken,
                        zoomLevel: documentState.zoomLevel,
                        findRequest: documentState.findRequest,
                        commentSelectionRequest: commentSelectionRequest,
                        onAddComment: { selection, body in
                            documentState.addComment(startOffset: selection.start, endOffset: selection.end, body: body)
                        },
                        onUpdateComment: { id, body in
                            documentState.updateComment(id: id, body: body)
                        },
                        onDeleteComment: { id in
                            documentState.deleteComment(id: id)
                        }
                    )
                }
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .navigationTitle(documentState.title)
        .background(WindowAccessor { window in
            window.tabbingMode = .preferred
            window.documentState = documentState
        })
        .onChange(of: documentState.findQuery) { _ in
            documentState.updateFindResults()
        }
        .onChange(of: documentState.htmlContent) { _ in
            if documentState.isShowingFindBar {
                documentState.updateFindResults()
            }
        }
        .onExitCommand {
            if documentState.isShowingFindBar {
                documentState.hideFindBar()
            }
        }
        .overlay(alignment: .trailing) {
            ZStack(alignment: .trailing) {
                Color.clear
                    .frame(width: 12)
                    .contentShape(Rectangle())
                    .onHover { hovering in
                        isHoveringEdge = hovering
                    }

                if showOutline {
                    OutlineSidebar(items: documentState.outlineItems) { item in
                        scrollRequest = ScrollRequest(id: item.anchorID, token: UUID())
                    }
                    .onHover { hovering in
                        isHoveringSidebar = hovering
                    }
                    .transition(.move(edge: .trailing))
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            if documentState.fileChanged || documentState.isShowingFindBar {
                VStack(alignment: .trailing, spacing: 8) {
                    if documentState.fileChanged {
                        Button(action: {
                            documentState.reload()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 11, weight: .medium))
                                Text("File changed")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.orange.opacity(0.9))
                            .foregroundColor(.white)
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }

                    if documentState.isShowingFindBar {
                        FindBar(
                            query: $documentState.findQuery,
                            focusToken: documentState.findFocusToken,
                            onNext: { documentState.findNext() },
                            onPrevious: { documentState.findPrevious() },
                            onClose: { documentState.hideFindBar() }
                        )
                    }
                }
                .padding(12)
            }
        }
        .toolbar {
            if canShowComments {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        requestCommentSelection()
                    }) {
                        Label("Add Comment", systemImage: "text.bubble")
                            .labelStyle(.iconOnly)
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .help("Add Comment")
                    .keyboardShortcut("m", modifiers: [.command, .shift])
                }
            }
            if canShowOutline {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isOutlinePinned.toggle()
                        }
                    }) {
                        Label("Table of Contents", systemImage: "sidebar.right")
                            .labelStyle(.iconOnly)
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.secondary)
                    .symbolVariant(isOutlinePinned ? .fill : .none)
                    .help(isOutlinePinned ? "Hide Table of Contents" : "Show Table of Contents")
                }
            }
        }
    }

    private func requestCommentSelection() {
        commentSelectionRequest = UUID()
    }
}

struct OutlineSidebar: View {
    let items: [OutlineItem]
    let onSelect: (OutlineItem) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                if items.isEmpty {
                    Text("No headings")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(items) { item in
                        OutlineRow(item: item, onSelect: onSelect)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 240, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.95))
        .overlay(
            Rectangle()
                .fill(Color(NSColor.separatorColor))
                .frame(width: 1),
            alignment: .leading
        )
    }
}

struct OutlineRow: View {
    let item: OutlineItem
    let onSelect: (OutlineItem) -> Void

    private var indent: CGFloat {
        CGFloat(max(item.level - 1, 0)) * 12
    }

    private var fontSize: CGFloat {
        item.level == 1 ? 13 : 12
    }

    private var fontWeight: Font.Weight {
        item.level == 1 ? .semibold : .regular
    }

    private var textColor: Color {
        item.level <= 2 ? .primary : .secondary
    }

    var body: some View {
        Button(action: {
            onSelect(item)
        }) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(item.title)
                    .font(.system(size: fontSize, weight: fontWeight))
                    .foregroundColor(textColor)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 2)
            .padding(.leading, indent)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct FindBar: View {
    @Binding var query: String
    let focusToken: UUID
    let onNext: () -> Void
    let onPrevious: () -> Void
    let onClose: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Find", text: $query)
                .textFieldStyle(.plain)
                .frame(width: 200)
                .focused($isFocused)
                .onSubmit {
                    onNext()
                }
            Button(action: onPrevious) {
                Image(systemName: "chevron.up")
            }
            .buttonStyle(.plain)
            Button(action: onNext) {
                Image(systemName: "chevron.down")
            }
            .buttonStyle(.plain)
            Button(action: onClose) {
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.95))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(NSColor.separatorColor))
        )
        .cornerRadius(8)
        .shadow(radius: 6)
        .onAppear {
            DispatchQueue.main.async {
                isFocused = true
            }
        }
        .onChange(of: focusToken) { _ in
            DispatchQueue.main.async {
                isFocused = true
            }
        }
        .onExitCommand {
            onClose()
        }
    }
}
