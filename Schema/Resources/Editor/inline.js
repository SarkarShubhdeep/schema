// Inline editors (#123), such as the writing above a list's tasks: the app
// sizes the web view to the content, so report how tall it is, menus that
// stick out below included.
(() => {
  const root = document.documentElement;
  if (!root.classList.contains("is-inline")) return;
  let last = 0;
  const measure = () => {
    let bottom = 0;
    for (const el of document.body.children) {
      if (el.tagName === "SCRIPT") continue;
      const rect = el.getBoundingClientRect();
      if (rect.height > 0) bottom = Math.max(bottom, rect.bottom + window.scrollY);
    }
    const height = Math.ceil(bottom);
    if (height !== last) {
      last = height;
      window.webkit?.messageHandlers?.schema?.postMessage({ type: "height", value: height });
    }
  };
  const start = () => {
    new ResizeObserver(measure).observe(document.body);
    const editor = document.getElementById("editor");
    if (editor) new ResizeObserver(measure).observe(editor);
    new MutationObserver(measure).observe(document.body, { childList: true, subtree: true, attributes: true, attributeFilter: ["style", "class"] });
    measure();
  };
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start);
  else start();
})();
