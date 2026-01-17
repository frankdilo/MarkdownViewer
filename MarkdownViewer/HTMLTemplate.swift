import Foundation

enum HTMLTemplate {
    static func wrap(body: String, title: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>\(title)</title>
            <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/github.min.css" media="(prefers-color-scheme: light)">
            <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/github-dark.min.css" media="(prefers-color-scheme: dark)">
            <script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js"></script>
            <style>
                :root {
                    color-scheme: light dark;
                    --color-fg-default: #1f2328;
                    --color-fg-muted: #656d76;
                    --color-canvas-default: #ffffff;
                    --color-canvas-subtle: #f6f8fa;
                    --color-border-default: #d0d7de;
                    --color-border-muted: hsla(210,18%,87%,1);
                    --color-accent-fg: #0969da;
                    --color-danger-fg: #d1242f;
                }
                @media (prefers-color-scheme: dark) {
                    :root {
                        --color-fg-default: #e6edf3;
                        --color-fg-muted: #8d96a0;
                        --color-canvas-default: #0d1117;
                        --color-canvas-subtle: #161b22;
                        --color-border-default: #30363d;
                        --color-border-muted: #21262d;
                        --color-accent-fg: #4493f8;
                        --color-danger-fg: #f85149;
                    }
                }
                * { box-sizing: border-box; }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Noto Sans', Helvetica, Arial, sans-serif;
                    font-size: 14px;
                    line-height: 1.5;
                    word-wrap: break-word;
                    max-width: 980px;
                    margin: 0 auto;
                    padding: 32px 28px;
                    background-color: var(--color-canvas-default);
                    color: var(--color-fg-default);
                }
                h1, h2, h3, h4, h5, h6 {
                    margin-top: 24px;
                    margin-bottom: 16px;
                    font-weight: 600;
                    line-height: 1.25;
                }
                h1 { font-size: 2em; padding-bottom: 0.3em; border-bottom: 1px solid var(--color-border-muted); }
                h2 { font-size: 1.5em; padding-bottom: 0.3em; border-bottom: 1px solid var(--color-border-muted); }
                h3 { font-size: 1.25em; }
                h4 { font-size: 1em; }
                h5 { font-size: 0.875em; }
                h6 { font-size: 0.85em; color: var(--color-fg-muted); }
                p { margin-top: 0; margin-bottom: 10px; }
                a {
                    color: var(--color-accent-fg);
                    text-decoration: none;
                }
                a:hover { text-decoration: underline; }
                code {
                    font-family: ui-monospace, SFMono-Regular, 'SF Mono', Menlo, Consolas, 'Liberation Mono', monospace;
                    font-size: 85%;
                    padding: 0.2em 0.4em;
                    margin: 0;
                    background-color: var(--color-canvas-subtle);
                    border-radius: 6px;
                }
                pre {
                    margin-top: 0;
                    margin-bottom: 16px;
                    padding: 16px;
                    overflow: auto;
                    font-size: 85%;
                    line-height: 1.45;
                    background-color: var(--color-canvas-subtle);
                    border-radius: 6px;
                }
                pre code {
                    display: block;
                    padding: 0;
                    margin: 0;
                    overflow: visible;
                    line-height: inherit;
                    word-wrap: normal;
                    background-color: transparent;
                    border: 0;
                    font-size: 100%;
                }
                blockquote {
                    margin: 0 0 16px 0;
                    padding: 0 1em;
                    color: var(--color-fg-muted);
                    border-left: 0.25em solid var(--color-border-default);
                }
                blockquote > :first-child { margin-top: 0; }
                blockquote > :last-child { margin-bottom: 0; }
                ul, ol {
                    margin-top: 0;
                    margin-bottom: 16px;
                    padding-left: 2em;
                }
                li { margin-top: 0.25em; }
                li + li { margin-top: 0.25em; }
                ul ul, ul ol, ol ol, ol ul {
                    margin-top: 0;
                    margin-bottom: 0;
                }
                hr {
                    height: 0.25em;
                    padding: 0;
                    margin: 24px 0;
                    background-color: var(--color-border-default);
                    border: 0;
                }
                table {
                    border-spacing: 0;
                    border-collapse: collapse;
                    margin-top: 0;
                    margin-bottom: 16px;
                    display: block;
                    width: max-content;
                    max-width: 100%;
                    overflow: auto;
                }
                table th {
                    font-weight: 600;
                }
                table th, table td {
                    padding: 6px 13px;
                    border: 1px solid var(--color-border-default);
                }
                table tr {
                    background-color: var(--color-canvas-default);
                    border-top: 1px solid var(--color-border-muted);
                }
                table tr:nth-child(2n) {
                    background-color: var(--color-canvas-subtle);
                }
                img {
                    max-width: 100%;
                    box-sizing: content-box;
                    background-color: var(--color-canvas-default);
                }
                del { color: var(--color-fg-muted); }
                strong { font-weight: 600; }
                em { font-style: italic; }
                .front-matter {
                    margin-bottom: 24px;
                    padding: 12px 16px;
                    background-color: var(--color-canvas-subtle);
                    border-radius: 6px;
                    border: 1px solid var(--color-border-muted);
                }
                .front-matter-table {
                    display: table;
                    width: auto;
                    margin: 0;
                    font-size: 12px;
                    border: none;
                }
                .front-matter-table tr {
                    background: transparent !important;
                    border: none;
                }
                .front-matter-table td {
                    padding: 2px 0;
                    border: none;
                    vertical-align: top;
                }
                .front-matter-table .fm-key {
                    color: var(--color-fg-muted);
                    padding-right: 12px;
                    white-space: nowrap;
                    font-weight: 500;
                }
                .front-matter-table .fm-value {
                    color: var(--color-fg-default);
                    font-family: ui-monospace, SFMono-Regular, 'SF Mono', Menlo, monospace;
                }
                .mv-comment-highlight {
                    background-color: rgba(255, 230, 153, 0.6);
                    border-radius: 4px;
                    padding: 0 2px;
                    cursor: pointer;
                    box-decoration-break: clone;
                    -webkit-box-decoration-break: clone;
                }
                .mv-comment-highlight:hover {
                    background-color: rgba(255, 214, 102, 0.7);
                }
                .mv-comment-bubble {
                    position: fixed;
                    z-index: 9999;
                    padding: 6px 12px;
                    border-radius: 999px;
                    border: 1px solid var(--color-border-default);
                    background-color: var(--color-canvas-default);
                    color: var(--color-fg-default);
                    font-size: 12px;
                    font-weight: 600;
                    box-shadow: 0 6px 18px rgba(0, 0, 0, 0.12);
                    cursor: pointer;
                    user-select: none;
                }
                .mv-comment-bubble:hover {
                    border-color: var(--color-accent-fg);
                    color: var(--color-accent-fg);
                }
                .mv-comment-panel {
                    position: fixed;
                    z-index: 10000;
                    width: 320px;
                    padding: 12px;
                    border-radius: 10px;
                    border: 1px solid var(--color-border-default);
                    background-color: var(--color-canvas-default);
                    box-shadow: 0 12px 32px rgba(0, 0, 0, 0.18);
                    color: var(--color-fg-default);
                    font-size: 12px;
                }
                .mv-comment-panel h4 {
                    margin: 0 0 6px 0;
                    font-size: 13px;
                }
                .mv-comment-meta {
                    display: flex;
                    justify-content: space-between;
                    align-items: center;
                    margin-bottom: 6px;
                }
                .mv-comment-id {
                    display: inline-flex;
                    align-items: center;
                    gap: 6px;
                    font-size: 11px;
                    color: var(--color-fg-muted);
                    cursor: pointer;
                }
                .mv-comment-id button {
                    border: none;
                    background: none;
                    color: inherit;
                    cursor: pointer;
                    font-size: 11px;
                }
                .mv-comment-text {
                    width: 100%;
                    height: 110px;
                    border-radius: 8px;
                    border: 1px solid var(--color-border-default);
                    padding: 8px;
                    font-size: 12px;
                    resize: vertical;
                    background-color: var(--color-canvas-default);
                    color: var(--color-fg-default);
                }
                .mv-comment-selection {
                    font-size: 11px;
                    color: var(--color-fg-muted);
                    margin-bottom: 8px;
                }
                .mv-comment-actions {
                    display: flex;
                    gap: 8px;
                    margin-top: 10px;
                    align-items: center;
                }
                .mv-comment-actions button {
                    border-radius: 6px;
                    border: 1px solid var(--color-border-default);
                    padding: 6px 10px;
                    background-color: var(--color-canvas-subtle);
                    color: var(--color-fg-default);
                    cursor: pointer;
                    font-size: 11px;
                }
                .mv-comment-actions button.mv-primary {
                    background-color: var(--color-accent-fg);
                    color: #ffffff;
                    border-color: transparent;
                }
                .mv-comment-actions button.mv-danger {
                    color: var(--color-danger-fg);
                    border-color: var(--color-danger-fg);
                    background: transparent;
                }
                .mv-comment-timestamps {
                    margin-top: 6px;
                    color: var(--color-fg-muted);
                    font-size: 10px;
                }
                .mv-comment-toast {
                    position: fixed;
                    z-index: 10001;
                    padding: 6px 10px;
                    border-radius: 6px;
                    background-color: rgba(209, 36, 47, 0.9);
                    color: #ffffff;
                    font-size: 11px;
                    pointer-events: none;
                }
                @media (prefers-color-scheme: dark) {
                    .mv-comment-highlight {
                        background-color: rgba(255, 205, 87, 0.25);
                    }
                    .mv-comment-highlight:hover {
                        background-color: rgba(255, 205, 87, 0.4);
                    }
                }
                mark.mv-find-match {
                    background-color: #fff3b0;
                    color: #111111;
                    border-radius: 2px;
                }
                mark.mv-find-active {
                    background-color: #ffd24d;
                }
            </style>
        </head>
        <body>
            <div id="mv-document">
                \(body)
            </div>
            <div id="mv-comment-root"></div>
            <script>hljs.highlightAll();</script>
            <script crossorigin src="https://unpkg.com/react@18/umd/react.production.min.js"></script>
            <script crossorigin src="https://unpkg.com/react-dom@18/umd/react-dom.production.min.js"></script>
            <script>
                (function() {
                    var state = {
                        query: "",
                        matches: [],
                        index: -1
                    };

                    function clearHighlights() {
                        var marks = document.querySelectorAll("mark.mv-find-match");
                        for (var i = 0; i < marks.length; i++) {
                            var mark = marks[i];
                            var parent = mark.parentNode;
                            if (!parent) {
                                continue;
                            }
                            parent.replaceChild(document.createTextNode(mark.textContent), mark);
                            parent.normalize();
                        }
                        state.matches = [];
                        state.index = -1;
                    }

                    function collectTextNodes() {
                        var nodes = [];
                        var root = document.getElementById("mv-document") || document.body;
                        var walker = document.createTreeWalker(
                            root,
                            NodeFilter.SHOW_TEXT,
                            {
                                acceptNode: function(node) {
                                    if (!node.nodeValue || !node.nodeValue.trim()) {
                                        return NodeFilter.FILTER_REJECT;
                                    }
                                    var parent = node.parentNode;
                                    if (!parent) {
                                        return NodeFilter.FILTER_REJECT;
                                    }
                                    if (parent.closest("script, style, mark")) {
                                        return NodeFilter.FILTER_REJECT;
                                    }
                                    return NodeFilter.FILTER_ACCEPT;
                                }
                            }
                        );
                        var current = walker.nextNode();
                        while (current) {
                            nodes.push(current);
                            current = walker.nextNode();
                        }
                        return nodes;
                    }

                    function highlightAll(query) {
                        clearHighlights();
                        state.query = query;
                        if (!query) {
                            return;
                        }
                        var lowerQuery = query.toLowerCase();
                        var nodes = collectTextNodes();
                        for (var i = 0; i < nodes.length; i++) {
                            var node = nodes[i];
                            var text = node.nodeValue;
                            var fragment = document.createDocumentFragment();
                            var lowerText = text.toLowerCase();
                            var startIndex = 0;
                            var matchIndex = lowerText.indexOf(lowerQuery, startIndex);
                            if (matchIndex === -1) {
                                continue;
                            }
                            while (matchIndex !== -1) {
                                var endIndex = matchIndex + query.length;
                                if (matchIndex > startIndex) {
                                    fragment.appendChild(document.createTextNode(text.slice(startIndex, matchIndex)));
                                }
                                var mark = document.createElement("mark");
                                mark.className = "mv-find-match";
                                mark.textContent = text.slice(matchIndex, endIndex);
                                fragment.appendChild(mark);
                                state.matches.push(mark);
                                startIndex = endIndex;
                                matchIndex = lowerText.indexOf(lowerQuery, startIndex);
                            }
                            if (startIndex < text.length) {
                                fragment.appendChild(document.createTextNode(text.slice(startIndex)));
                            }
                            node.parentNode.replaceChild(fragment, node);
                        }
                        if (state.matches.length > 0) {
                            state.index = 0;
                            updateActive();
                        }
                    }

                    function updateActive() {
                        if (state.matches.length === 0 || state.index < 0) {
                            return;
                        }
                        for (var i = 0; i < state.matches.length; i++) {
                            if (i === state.index) {
                                state.matches[i].classList.add("mv-find-active");
                            } else {
                                state.matches[i].classList.remove("mv-find-active");
                            }
                        }
                        var target = state.matches[state.index];
                        if (target && target.scrollIntoView) {
                            target.scrollIntoView({ block: "center", inline: "nearest" });
                        }
                    }

                    function step(direction) {
                        if (state.matches.length === 0) {
                            return;
                        }
                        if (direction === "backward") {
                            state.index = (state.index - 1 + state.matches.length) % state.matches.length;
                        } else {
                            state.index = (state.index + 1) % state.matches.length;
                        }
                        updateActive();
                    }

                    window.__markdownViewerFind = function(payload) {
                        if (!payload) {
                            return;
                        }
                        var query = payload.query || "";
                        var direction = payload.direction || "forward";
                        var reset = Boolean(payload.reset);
                        if (reset || query !== state.query) {
                            highlightAll(query);
                        } else {
                            step(direction);
                        }
                    };
                })();
                (function() {
                    function utf8Length(text) {
                        return new TextEncoder().encode(text).length;
                    }

                    function findTextSpan(node) {
                        if (!node) {
                            return null;
                        }
                        if (node.nodeType === Node.TEXT_NODE) {
                            if (!node.parentElement) {
                                return null;
                            }
                            return node.parentElement.closest("[data-mv-text-start]");
                        }
                        if (node.nodeType === Node.ELEMENT_NODE) {
                            return node.closest("[data-mv-text-start]");
                        }
                        return null;
                    }

                    function isDisallowedSelection(node) {
                        if (!node || !node.parentElement) {
                            return false;
                        }
                        return Boolean(node.parentElement.closest("code, pre, a, [data-mv-frontmatter], .mv-comment-panel"));
                    }

                    function getSelectionInfo() {
                        var selection = window.getSelection();
                        if (!selection || selection.rangeCount === 0) {
                            return { error: "Select text to add a comment." };
                        }
                        var range = selection.getRangeAt(0);
                        if (range.collapsed) {
                            return { error: "Select text to add a comment." };
                        }
                        if (isDisallowedSelection(range.startContainer) || isDisallowedSelection(range.endContainer)) {
                            return { error: "Comments aren't supported inside code, links, or front matter." };
                        }
                        var startSpan = findTextSpan(range.startContainer);
                        var endSpan = findTextSpan(range.endContainer);
                        if (!startSpan || !endSpan) {
                            return { error: "Selection must be inside the document body." };
                        }
                        var startBase = parseInt(startSpan.dataset.mvTextStart || "0", 10);
                        var endBase = parseInt(endSpan.dataset.mvTextStart || "0", 10);
                        var startText = range.startContainer.nodeType === Node.TEXT_NODE ? (range.startContainer.nodeValue || "") : "";
                        var endText = range.endContainer.nodeType === Node.TEXT_NODE ? (range.endContainer.nodeValue || "") : "";
                        var startOffset = startBase + utf8Length(startText.slice(0, range.startOffset));
                        var endOffset = endBase + utf8Length(endText.slice(0, range.endOffset));
                        if (!Number.isFinite(startOffset) || !Number.isFinite(endOffset) || endOffset <= startOffset) {
                            return { error: "Selection isn't valid for comments." };
                        }
                        var rect = range.getBoundingClientRect();
                        return {
                            start: startOffset,
                            end: endOffset,
                            text: selection.toString(),
                            rect: {
                                x: rect.x,
                                y: rect.y,
                                width: rect.width,
                                height: rect.height
                            }
                        };
                    }

                    function clearCommentHighlights() {
                        var highlights = document.querySelectorAll("span.mv-comment-highlight");
                        for (var i = highlights.length - 1; i >= 0; i--) {
                            var highlight = highlights[i];
                            var parent = highlight.parentNode;
                            if (!parent) {
                                continue;
                            }
                            while (highlight.firstChild) {
                                parent.insertBefore(highlight.firstChild, highlight);
                            }
                            parent.removeChild(highlight);
                            parent.normalize();
                        }
                    }

                    function applyCommentHighlights() {
                        clearCommentHighlights();
                        var root = document.getElementById("mv-document") || document.body;
                        if (!root) {
                            return;
                        }
                        var walker = document.createTreeWalker(root, NodeFilter.SHOW_COMMENT, null, false);
                        var starts = {};
                        var ends = {};
                        var payloads = {};
                        var node;
                        while ((node = walker.nextNode())) {
                            var text = (node.nodeValue || "").trim();
                            if (text.indexOf("MV-COMMENT-START") === 0) {
                                var jsonText = text.slice("MV-COMMENT-START".length).trim();
                                try {
                                    var payload = JSON.parse(jsonText);
                                    if (payload && payload.id) {
                                        starts[payload.id] = node;
                                        payloads[payload.id] = jsonText;
                                    }
                                } catch (e) {
                                }
                            } else if (text.indexOf("MV-COMMENT-END") === 0) {
                                var id = text.slice("MV-COMMENT-END".length).trim();
                                if (id) {
                                    ends[id] = node;
                                }
                            }
                        }

                        Object.keys(starts).forEach(function(id) {
                            var startNode = starts[id];
                            var endNode = ends[id];
                            if (!startNode || !endNode) {
                                return;
                            }
                            var range = document.createRange();
                            range.setStartAfter(startNode);
                            range.setEndBefore(endNode);
                            var wrapper = document.createElement("span");
                            wrapper.className = "mv-comment-highlight";
                            wrapper.dataset.commentId = id;
                            if (payloads[id]) {
                                wrapper.dataset.commentPayload = payloads[id];
                            }
                            var fragment = range.extractContents();
                            wrapper.appendChild(fragment);
                            range.insertNode(wrapper);
                        });
                    }

                    function decodeBase64UTF8(value) {
                        try {
                            var decoded = atob(value);
                            var escaped = decoded.split("").map(function(char) {
                                var hex = char.charCodeAt(0).toString(16).padStart(2, "0");
                                return "%" + hex;
                            }).join("");
                            return decodeURIComponent(escaped);
                        } catch (error) {
                            try {
                                return atob(value);
                            } catch (innerError) {
                                return "";
                            }
                        }
                    }

                    function decodeCommentPayload(payloadText) {
                        if (!payloadText) {
                            return null;
                        }
                        try {
                            var payload = JSON.parse(payloadText);
                            var body = decodeBase64UTF8(payload.bodyB64 || "");
                            return {
                                id: payload.id || "",
                                created: payload.created || "",
                                updated: payload.updated || "",
                                body: body
                            };
                        } catch (error) {
                            return null;
                        }
                    }

                    function clamp(value, minValue, maxValue) {
                        return Math.max(minValue, Math.min(maxValue, value));
                    }

                    function positionNearRect(rect, width, height, offsetX, offsetY) {
                        var x = rect.x + rect.width + offsetX;
                        var y = rect.y + offsetY;
                        x = clamp(x, 8, window.innerWidth - width - 8);
                        y = clamp(y, 8, window.innerHeight - height - 8);
                        return { left: x + "px", top: y + "px" };
                    }

                    function sendMessage(name, payload) {
                        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers[name]) {
                            window.webkit.messageHandlers[name].postMessage(payload);
                        }
                    }

                    function CommentApp() {
                        var useState = React.useState;
                        var useEffect = React.useEffect;
                        var useRef = React.useRef;
                        var editorRef = useRef(null);
                        var selectionRef = useRef(null);
                        var toastTimer = useRef(null);
                        var renderToken = useRef(0);

                        var _useState = useState(null);
                        var selection = _useState[0];
                        var setSelection = _useState[1];

                        var _useState2 = useState(null);
                        var editor = _useState2[0];
                        var setEditor = _useState2[1];

                        var _useState3 = useState("");
                        var textValue = _useState3[0];
                        var setTextValue = _useState3[1];

                        var _useState4 = useState("");
                        var toast = _useState4[0];
                        var setToast = _useState4[1];

                        function showToast(message) {
                            setToast(message);
                            if (toastTimer.current) {
                                clearTimeout(toastTimer.current);
                            }
                            toastTimer.current = setTimeout(function() {
                                setToast("");
                            }, 1800);
                        }

                        function openEditorForSelection(info) {
                            setEditor({ mode: "add", selection: info, rect: info.rect });
                            setTextValue("");
                        }

                        function openEditorForComment(comment, rect) {
                            if (!comment) {
                                return;
                            }
                            setEditor({ mode: "edit", comment: comment, rect: rect });
                            setTextValue(comment.body || "");
                        }

                        function closeEditor() {
                            setEditor(null);
                            setSelection(null);
                        }

                        function openFromSelection() {
                            var info = getSelectionInfo();
                            if (info && !info.error) {
                                openEditorForSelection(info);
                            } else {
                                showToast(info && info.error ? info.error : "Select text to add a comment.");
                            }
                        }

                        useEffect(function() {
                            function handleSelectionChange() {
                                if (editor) {
                                    return;
                                }
                                var info = getSelectionInfo();
                                if (info && !info.error) {
                                    selectionRef.current = info;
                                    setSelection(info);
                                } else {
                                    selectionRef.current = null;
                                    setSelection(null);
                                }
                            }

                            function handleClick(event) {
                                var target = event.target;
                                if (!target) {
                                    return;
                                }
                                var highlight = target.closest(".mv-comment-highlight");
                                if (highlight) {
                                    var rect = highlight.getBoundingClientRect();
                                    var payload = decodeCommentPayload(highlight.dataset.commentPayload || "");
                                    openEditorForComment(payload, rect);
                                    return;
                                }

                                if (editorRef.current && !editorRef.current.contains(target)) {
                                    closeEditor();
                                }
                            }

                            document.addEventListener("selectionchange", handleSelectionChange);
                            document.addEventListener("click", handleClick);
                            window.addEventListener("resize", closeEditor);
                            window.addEventListener("scroll", closeEditor, true);

                            return function() {
                                document.removeEventListener("selectionchange", handleSelectionChange);
                                document.removeEventListener("click", handleClick);
                                window.removeEventListener("resize", closeEditor);
                                window.removeEventListener("scroll", closeEditor, true);
                            };
                        }, [editor]);

                        useEffect(function() {
                            window.__markdownViewerCommentUI = {
                                openFromSelection: openFromSelection,
                                refresh: applyCommentHighlights
                            };
                        });

                        function submitComment() {
                            var trimmed = textValue.trim();
                            if (!trimmed) {
                                showToast("Comment cannot be empty.");
                                return;
                            }
                            if (!editor) {
                                return;
                            }
                            if (editor.mode === "add") {
                                var info = editor.selection;
                                sendMessage("commentAdd", {
                                    start: info.start,
                                    end: info.end,
                                    body: trimmed
                                });
                            } else if (editor.mode === "edit") {
                                sendMessage("commentUpdate", {
                                    id: editor.comment.id,
                                    body: trimmed
                                });
                            }
                            closeEditor();
                        }

                        function deleteComment() {
                            if (!editor || editor.mode !== "edit") {
                                return;
                            }
                            sendMessage("commentDelete", { id: editor.comment.id });
                            closeEditor();
                        }

                        function copyID() {
                            if (!editor || editor.mode !== "edit") {
                                return;
                            }
                            var value = editor.comment.id || "";
                            if (!value) {
                                return;
                            }
                            if (navigator.clipboard && navigator.clipboard.writeText) {
                                navigator.clipboard.writeText(value).catch(function() {});
                            } else {
                                var input = document.createElement("input");
                                input.value = value;
                                document.body.appendChild(input);
                                input.select();
                                document.execCommand("copy");
                                document.body.removeChild(input);
                            }
                            showToast("Copied " + value);
                        }

                        function formatTimestamp(value) {
                            if (!value) {
                                return "";
                            }
                            var date = new Date(value);
                            if (isNaN(date.getTime())) {
                                return value;
                            }
                            return date.toLocaleString();
                        }

                        var bubble = null;
                        if (selection && !editor) {
                            var bubbleStyle = positionNearRect(selection.rect, 90, 28, 8, -6);
                            bubble = React.createElement(
                                "button",
                                {
                                    className: "mv-comment-bubble",
                                    style: bubbleStyle,
                                    onClick: function() {
                                        openEditorForSelection(selection);
                                    }
                                },
                                "Comment"
                            );
                        }

                        var panel = null;
                        if (editor) {
                            renderToken.current += 1;
                            var panelRect = editor.rect || (selection && selection.rect) || { x: 16, y: 16, width: 0, height: 0 };
                            var panelStyle = positionNearRect(panelRect, 320, 240, 8, 8);
                            var selectionPreview = editor.mode === "add" && editor.selection ? editor.selection.text : "";
                            panel = React.createElement(
                                "div",
                                {
                                    className: "mv-comment-panel",
                                    style: panelStyle,
                                    ref: editorRef,
                                    key: renderToken.current
                                },
                                React.createElement(
                                    "div",
                                    { className: "mv-comment-meta" },
                                    React.createElement("h4", null, editor.mode === "add" ? "Add Comment" : "Comment"),
                                    editor.mode === "edit" && React.createElement(
                                        "div",
                                        { className: "mv-comment-id" },
                                        React.createElement(
                                            "button",
                                            { type: "button", onClick: copyID },
                                            editor.comment.id
                                        )
                                    )
                                ),
                                selectionPreview
                                    ? React.createElement("div", { className: "mv-comment-selection" }, selectionPreview)
                                    : null,
                                React.createElement("textarea", {
                                    className: "mv-comment-text",
                                    value: textValue,
                                    onChange: function(event) {
                                        setTextValue(event.target.value);
                                    }
                                }),
                                editor.mode === "edit" && React.createElement(
                                    "div",
                                    { className: "mv-comment-timestamps" },
                                    "Created ",
                                    formatTimestamp(editor.comment.created),
                                    " • Edited ",
                                    formatTimestamp(editor.comment.updated)
                                ),
                                React.createElement(
                                    "div",
                                    { className: "mv-comment-actions" },
                                    React.createElement(
                                        "button",
                                        { type: "button", onClick: closeEditor },
                                        "Cancel"
                                    ),
                                    editor.mode === "edit"
                                        ? React.createElement(
                                            "button",
                                            { type: "button", className: "mv-danger", onClick: deleteComment },
                                            "Delete"
                                        )
                                        : null,
                                    React.createElement(
                                        "button",
                                        { type: "button", className: "mv-primary", onClick: submitComment },
                                        "Save"
                                    )
                                )
                            );
                        }

                        var toastView = toast
                            ? React.createElement(
                                "div",
                                { className: "mv-comment-toast", style: { left: "16px", top: "16px" } },
                                toast
                            )
                            : null;

                        return React.createElement(
                            React.Fragment,
                            null,
                            bubble,
                            panel,
                            toastView
                        );
                    }

                    function mountReactApp() {
                        applyCommentHighlights();
                        var root = document.getElementById("mv-comment-root");
                        if (!root) {
                            root = document.createElement("div");
                            root.id = "mv-comment-root";
                            document.body.appendChild(root);
                        }
                        if (window.ReactDOM && window.React) {
                            ReactDOM.createRoot(root).render(React.createElement(CommentApp));
                        }
                    }

                    if (document.readyState === "loading") {
                        document.addEventListener("DOMContentLoaded", mountReactApp);
                    } else {
                        mountReactApp();
                    }

                    window.__markdownViewerComments = {
                        getSelection: getSelectionInfo,
                        refresh: applyCommentHighlights
                    };
                })();
            </script>
        </body>
        </html>
        """
    }
}
