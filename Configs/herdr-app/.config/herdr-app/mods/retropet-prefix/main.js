// tmux-style prefix key. keys.json binds ctrl-b / ctrl-space to `mod.open:retropet-prefix`; this
// invisible popup sets shared "prefix.armed" (retropet-tabs colors the active tab), takes the next key, runs its action from bindings.json (same action format as keys.json) and closes.
// The prefix again (keys.json `mod:prefix` → `prefix.send:<key>`) sends it to the terminal.
// Esc or an unknown key cancel.

import { View, div } from "gpui-kit";
import { run, props, closeOverlay, commands, readTextFile, appHome, nextCommand, focused, hc, setShared } from "herdr";

const MODIFIERS = new Set(["shift", "control", "ctrl", "alt", "super", "cmd", "platform", "function", "fn"]);

function runAction(action) {
  if (action && typeof action === "object") return run(action.command, action.args ?? {});
  const i = action.indexOf(":");
  if (i < 0) return run(action, {});
  const name = action.slice(0, i);
  const value = action.slice(i + 1);
  const first = commands().find((c) => c.name === name)?.args?.[0]?.name;
  const v = /^\d+$/.test(value) && first === "index" ? Number(value) : value;
  return run(name, first ? { [first]: v } : {});
}

export default class Prefix extends View {
  init(_props, cx) {
    this.bindings = {};
    this.terminal = focused()?.terminal ?? null;
    this.handle = cx.focus_handle();
    setShared("prefix.armed", true);
    this.handle.focus();
    cx.timer.after(50, () => this.handle.focus());
    cx.spawn(async (cx) => {
      try { this.bindings = JSON.parse((await readTextFile(`${appHome()}/mods/retropet-prefix/bindings.json`)) ?? "{}"); }
      catch (e) { console.log("prefix: bindings.json", String(e)); }
      cx.notify();
    });
    cx.spawn(async (cx) => {
      for (;;) {
        const c = await nextCommand();
        if (c === "focus") { this.handle.focus(); continue; }
        if (c.startsWith("send:")) {
          const key = c.slice(5);
          this.dismiss();
          if (this.terminal) { try { await hc(["keys", this.terminal, key]); } catch (e) { console.log("prefix:", String(e)); } }
        }
      }
    });
  }

  dismiss() { setShared("prefix.armed", false); closeOverlay(props().overlay); }

  // The overlay went (click elsewhere, Esc, mod.open again): disarm.
  async close(_cx) { setShared("prefix.armed", false); }

  key(e, cx) {
    if (MODIFIERS.has(e.key)) return;
    cx.stop_propagation();
    const action = this.bindings[e.keystroke] ?? (e.key_char ? this.bindings[e.key_char] : undefined);
    this.dismiss();
    if (!action) return;
    try { runAction(action); } catch (err) { console.log("prefix:", String(err)); }
  }

  // Nothing to see: the armed prefix shows in the layout itself (retropet-tabs paints the active tab,
  // my-status adds a group), from shared "prefix.armed". This copy only takes the next key.
  render() {
    return div().id("prefix").size_full().track_focus(this.handle).on_key_down((e, cx) => this.key(e, cx));
  }
}
