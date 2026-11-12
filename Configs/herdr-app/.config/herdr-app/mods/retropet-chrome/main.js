// Modified from Herdr's shipped mod (Apache License 2.0, see LICENSE): pixel-art restyle of the footer.
import { View, div, image, svg } from "gpui-kit";
import { h_flex, v_flex } from "gpui-base";
import { theme, run, props, window, shared, setShared, updates, layout } from "herdr";

// Pixel look (fonts ship in mods/retropet-spaces/fonts). Only the footer is restyled.
const PX = "PxPlus IBM VGA 8x16";
const ORANGE = "#f0a04b";

function find(node, id) {
  if (node?.id === id) return node;
  for (const child of node?.children ?? []) {
    const found = find(child, id);
    if (found) return found;
  }
  return null;
}

// The sidebar's rail goes by its width, not a flag: dragging its edge narrows it too.
const narrow = () => (find(layout(), "sidebar")?.size?.px ?? Infinity) < 160;

// To the rail (on macOS wide enough for the traffic lights), or back to the width it had.
function toggleSidebar() {
  const width = find(layout(), "sidebar")?.size?.px;
  if (!narrow()) setShared("sidebar.width", width);
  // Mods edited before the rail went by width still read the flag.
  setShared("sidebar.collapsed", !narrow());
  run("layout.resize", { id: "sidebar", px: narrow() ? (shared("sidebar.width") ?? 268) : window()?.platform === "macos" ? 76 : 44 });
}

export default class WorkspaceChrome extends View {
  button(id, label, action) {
    const t = theme();
    return div().id(id).size(26).flex_none().flex().items_center().justify_center().rounded(6).text_color(t.muted).hover(s => s.bg(t.hover).text_color(t.foreground))
      .on_mouse_down("left", (_e, cx) => cx.stop_propagation()).on_click(action).child(label);
  }
  render() {
    const t = theme();
    const collapsed = narrow();
    if (props()?.footer) {
      // Rows like the spaces list: an orange bar and tint on hover, pixel caps.
      const row = (id, icon, label, dim, action) => h_flex().id(id).h(28).pl(9).pr(8).gap(9).items_center()
        .border_l(3).border_color(t.chrome + "00")
        .when(collapsed, el => el.relative().w(32).px(0).border_l(0).justify_center().tooltip(label))
        .text_color(dim ? t.dim : t.muted).hover(s => s.border_color(ORANGE).bg(ORANGE + "1f").text_color(ORANGE)).cursor_pointer()
        .on_click(action).child(svg(`mods/retropet-chrome/${icon}.svg`).size(14))
        .when(!collapsed, el => el.child(div().font_family(PX).text_size(16).line_height("16px").child(label.toUpperCase())));
      // An update waiting: a square, blinking.
      const ready = div().size(6).bg(ORANGE).loop("opacity", { from: 0.2, to: 1, period: 1200 });
      return v_flex().size_full().bg(t.chrome).border_t(2).border_color(t.border).px(8).pt(5).pb(8).gap(1)
        .when(collapsed, el => el.px(0).items_center())
        .child(row("settings", "settings", "Settings", false, () => run("app.settings"))
          .when(Boolean(updates().app.ready), el => el.child(collapsed ? ready.absolute().top(5).right(6) : ready)))
        .child(row("machine", "plus", "Add machine", true, () => run("mod.open", { name: "machine-add" })));
    }
    return h_flex().size_full().bg(t.chrome).pl(collapsed ? 6 : 14).pr(10).gap(4).items_center().text_size(13.5)
      .when(window()?.platform === "macos" && !window()?.fullscreen && !collapsed, el => el.pl(76))
      .when(!collapsed, el => el.child(h_flex().flex_1().gap(8).items_center().child(image("frame/welcome/herdr.png").size(20).rounded(5)).child(div().font_semibold().text_color(t.foreground).child("Herdr"))))
      .when(!collapsed, el => el.child(this.button("search", svg("mods/retropet-chrome/search.svg").size(15), () => run("mod.open", { name: "picker" }))))
      // On the macOS rail the traffic lights fill the row; the agents list's » unfolds it.
      .when(!(collapsed && window()?.platform === "macos"), el => el.child(this.button("sidebar-toggle", svg("mods/retropet-chrome/sidebar.svg").size(15), toggleSidebar)));
  }
}
