// From herdr-pixel-layout (github.com/murtuzaalisurti/herdr-pixel-layout), itself modified from
// Herdr's shipped mod (Apache License 2.0, see LICENSE): pixel-art restyle. Icons copied into ./art.
// A DOS-style status line: machine │ branch │ agents by status ··· [keys] COMMANDS

import { View, div, svg, image } from "gpui-kit";
import { h_flex } from "gpui-base";
import { spaces, agents, theme, run, window, keys } from "herdr";

// Pixel look (the font ships in mods/retropet-agents/fonts).
const PX = "PxPlus IBM VGA 8x16";
const ORANGE = "#f0a04b";
const ART = "mods/retropet-status/art";
// Most urgent first; each shows only when some agent is in it.
const STATES = [["blocked", "NEEDS YOU"], ["working", "BUSY"], ["done", "DONE"], ["idle", "IDLE"]];

export default class PixelStatus extends View {
  // The palette key as actually bound, not a hardcoded one; without a
  // binding the hint stays useful ("COMMANDS") instead of lying.
  keycap() {
    const mac = window()?.platform === "macos";
    const mod = { cmd: mac ? "⌘" : "Ctrl+", ctrl: mac ? "⌃" : "Ctrl+", shift: mac ? "⇧" : "Shift+", alt: mac ? "⌥" : "Alt+", option: mac ? "⌥" : "Alt+" };
    const b = keys().find((k) => k.section === "global" && k.action === "app.palette");
    const parts = b && b.keys.endsWith("--") ? [...b.keys.slice(0, -2).split("-"), "-"] : b?.keys.split("-");
    return parts ? parts.map((p) => mod[p.toLowerCase()] ?? p.toUpperCase()).join("") : null;
  }

  render() {
    const t = theme();
    const space = spaces().find((s) => s.active);
    const list = agents();
    const text = (s, color = t.muted) => div().flex_none().font_family(PX).text_size(16).line_height("16px").text_color(color).child(s);
    const bar = () => text("│", t.border);
    const counts = STATES.map(([s, word]) => [s, word, list.filter((a) => a.status === s).length]).filter(([, , n]) => n > 0);
    const key = this.keycap();
    return h_flex().size_full().px(12).gap(10).items_center().bg(t.chrome).border_t(2).border_color(t.border)
      .child(h_flex().flex_none().gap(7).items_center()
        .child(image(`${ART}/${space?.machine ? "server" : "monitor"}.svg`).w(14).h(12).flex_none())
        .child(text((space?.machine ?? "This machine").toUpperCase(), ORANGE)))
      .when(Boolean(space?.branch), (el) => el.child(bar()).child(h_flex().flex_none().min_w(0).gap(6).items_center()
        .child(svg("mods/workspace-chrome/git-branch.svg").size(13).text_color(t.dim))
        .child(div().max_w(220).truncate().font_family(PX).text_size(16).line_height("16px").text_color(t.muted).child(space.branch))))
      .child(bar())
      .child(text(`${list.length} AGENT${list.length === 1 ? "" : "S"}`))
      .children(counts.map(([s, word, n]) => h_flex().flex_none().gap(5).items_center()
        .child(div().size(6).flex_none().bg(t[s] ?? t.dim)
          .when(s === "working", (el) => el.loop("opacity", { from: 0.15, to: 1, period: 900 })))
        .child(text(`${n} ${word}`, t[s] ?? t.dim))))
      .child(div().flex_1())
      .child(h_flex().id("palette").flex_none().gap(7).items_center().cursor_pointer()
        .hover((s) => s.opacity(0.8))
        .on_click(() => run("app.palette"))
        // The keycap in the pixel font, unless it has macOS symbols the VGA font lacks (⌘ ⇧ ⌥ ⌃).
        .when(Boolean(key), (el) => el.child(div().px(4).h(18).flex().items_center().border_1().border_color(t.dim)
          .when(/^[\x20-\x7e]*$/.test(key), (k) => k.font_family(PX).text_size(14).line_height("14px"))
          .when(!/^[\x20-\x7e]*$/.test(key), (k) => k.text_size(11))
          .text_color(t.muted).child(key)))
        .child(text("COMMANDS", t.dim)));
  }
}
