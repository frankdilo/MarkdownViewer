(function() {
    function pickTheme() {
        var isDark = window.matchMedia && window.matchMedia("(prefers-color-scheme: dark)").matches;
        var themes = window.beautifulMermaid && window.beautifulMermaid.THEMES;
        var name = isDark ? "github-dark" : "github-light";
        return themes && themes[name] ? themes[name] : {};
    }

    async function renderDiagrams() {
        if (!window.beautifulMermaid || !window.beautifulMermaid.renderMermaid) {
            return;
        }

        var codeBlocks = document.querySelectorAll("pre > code.language-mermaid");
        if (!codeBlocks.length) {
            return;
        }

        var theme = pickTheme();
        var font = "Inter";
        if (document.body) {
            var bodyFont = window.getComputedStyle(document.body).fontFamily;
            if (bodyFont) {
                font = bodyFont;
            }
        }

        var renders = [];
        for (var i = 0; i < codeBlocks.length; i++) {
            (function(code) {
                var pre = code.parentNode;
                var source = code.textContent || "";
                var container = document.createElement("div");
                container.className = "mermaid";
                pre.parentNode.replaceChild(container, pre);

                var options = Object.assign({}, theme, { font: font });
                renders.push(
                    window.beautifulMermaid.renderMermaid(source, options).then(function(svg) {
                        container.innerHTML = svg;
                    }).catch(function() {
                        if (container.parentNode) {
                            container.parentNode.replaceChild(pre, container);
                        }
                    })
                );
            })(codeBlocks[i]);
        }

        if (renders.length) {
            try {
                await Promise.all(renders);
            } catch (error) {
                // Keep page usable even if one diagram fails.
            }
        }
    }

    renderDiagrams();
})();
