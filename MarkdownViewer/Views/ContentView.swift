import AppKit
import SwiftUI

struct ContentView: View {
    @StateObject private var documentState: DocumentState
    @State private var isHoveringEdge = false
    @State private var isHoveringSidebar = false
    @State private var isOutlinePinned = false
    @State private var scrollRequest: ScrollRequest?
    @State private var activeAnchorID: String?
    @ObservedObject private var appearanceSettings = AppearanceSettings.shared

    init(documentState: DocumentState = DocumentState()) {
        _documentState = StateObject(wrappedValue: documentState)
    }

    private var canShowOutline: Bool {
        !documentState.htmlContent.isEmpty
    }

    private var showPinnedOutline: Bool {
        canShowOutline && isOutlinePinned
    }

    private var showFloatingOutline: Bool {
        canShowOutline && !isOutlinePinned && (isHoveringEdge || isHoveringSidebar)
    }

    @ViewBuilder
    private var documentView: some View {
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
                onActiveAnchorChange: { anchorID in
                    activeAnchorID = anchorID
                }
            )
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            documentView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            if showPinnedOutline {
                OutlineSidebar(items: documentState.outlineItems, activeAnchorID: activeAnchorID) { item in
                    scrollRequest = ScrollRequest(id: item.anchorID, token: UUID())
                }
                .transition(.move(edge: .trailing))
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
            if documentState.fileChanged {
                withAnimation(.easeInOut(duration: 0.2)) { documentState.fileChanged = false }
            } else if documentState.isShowingFindBar {
                documentState.hideFindBar()
            }
        }
        .overlay(alignment: .trailing) {
            if canShowOutline && !isOutlinePinned {
                ZStack(alignment: .trailing) {
                    Color.clear
                        .frame(width: 12)
                        .contentShape(Rectangle())
                        .onHover { hovering in
                            isHoveringEdge = hovering
                        }

                    if showFloatingOutline {
                        OutlineSidebar(items: documentState.outlineItems, activeAnchorID: activeAnchorID) { item in
                            scrollRequest = ScrollRequest(id: item.anchorID, token: UUID())
                        }
                        .onHover { hovering in
                            isHoveringSidebar = hovering
                        }
                        .transition(.move(edge: .trailing))
                    }
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            if documentState.fileChanged || documentState.isShowingFindBar {
                VStack(alignment: .trailing, spacing: 8) {
                    if documentState.fileChanged {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 11, weight: .medium))
                            Text("File updated")
                                .font(.system(size: 11, weight: .medium))
                            Text("esc to dismiss")
                                .font(.system(size: 10))
                                .opacity(0.7)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.accentColor.opacity(0.85))
                        .foregroundColor(.white)
                        .cornerRadius(6)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) { documentState.fileChanged = false }
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
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
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    appearanceSettings.cycle()
                }) {
                    Label(appearanceSettings.label, systemImage: appearanceSettings.iconName)
                        .labelStyle(.iconOnly)
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(.secondary)
                .help(appearanceSettings.label)
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
}
