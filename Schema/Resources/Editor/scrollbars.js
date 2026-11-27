// Themed scroll bars (#121): mark the page while it scrolls, so the thin
// thumb in editor.css shows, then fades a moment after scrolling stops.
(() => {
  let timer;
  const root = document.documentElement;
  const show = () => {
    root.classList.add("is-scrolling");
    clearTimeout(timer);
    timer = setTimeout(() => root.classList.remove("is-scrolling"), 900);
  };
  window.addEventListener("scroll", show, { passive: true });
  window.addEventListener("wheel", show, { passive: true });
})();
