(function() {
    if (window.hljs && hljs.highlightAll) {
        hljs.highlightAll();
    }

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
        var walker = document.createTreeWalker(
            document.body,
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
                    if (parent.closest("script, style, mark, .mermaid")) {
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
