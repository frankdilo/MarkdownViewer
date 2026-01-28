(function() {
    var isDark = window.matchMedia && window.matchMedia("(prefers-color-scheme: dark)").matches;
    var theme = isDark ? "dark" : "default";

    mermaid.initialize({ startOnLoad: false, theme: theme });

    var codeBlocks = document.querySelectorAll("pre > code.language-mermaid");
    var containers = [];

    for (var i = 0; i < codeBlocks.length; i++) {
        var code = codeBlocks[i];
        var pre = code.parentNode;
        var source = code.textContent;

        var div = document.createElement("div");
        div.className = "mermaid";
        div.textContent = source;

        pre.parentNode.replaceChild(div, pre);
        containers.push(div);
    }

    if (containers.length > 0) {
        mermaid.run({ nodes: containers });
    }
})();
