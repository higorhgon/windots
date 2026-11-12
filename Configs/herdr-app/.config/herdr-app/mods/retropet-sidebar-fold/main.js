// Folds the sidebar to its rail and back, like the sidebar's own toggle button
// (workspace-chrome). prefix + b → mod.open:retropet-sidebar-fold. Invisible popup: acts, then closes.

import { View, div } from "gpui-kit";
import { run, layout, props, closeOverlay, shared, setShared, window } from "herdr";

function find(node, id) {
  if (node?.id === id) return node;
  for (const child of node?.children ?? []) {
    const found = find(child, id);
    if (found) return found;
  }
  return null;
}

export default class SidebarFold extends View {
  init(_props, cx) {
    const sidebar = find(layout(), "sidebar");
    if (sidebar) {
      if (sidebar.hidden) run("layout.show", { id: "sidebar" });
      const width = sidebar.size?.px ?? Infinity;
      const narrow = width < 160;
      if (!narrow && Number.isFinite(width)) setShared("sidebar.width", width);
      setShared("sidebar.collapsed", !narrow);
      run("layout.resize", { id: "sidebar", px: narrow ? (shared("sidebar.width") ?? 268) : window()?.platform === "macos" ? 76 : 44 });
    }
    cx.spawn(async () => closeOverlay(props()?.overlay));
  }

  render() {
    return div();
  }
}
