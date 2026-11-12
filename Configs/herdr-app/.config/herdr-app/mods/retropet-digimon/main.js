// Gives the focused agent the next Digimon in the retropet layout's cards (ctrl-shift-d → mod.open:retropet-digimon).
// Adds 1 to that agent's step in shared "retropet.digimon" ({address: step}); retropet-agents shows
// Digimon (hash(address) + step) mod count. Invisible popup: acts, then closes.

import { View, div } from "gpui-kit";
import { focused, agents, shared, setShared, props, closeOverlay } from "herdr";

export default class DigimonCycle extends View {
  init(_props, cx) {
    const f = focused();
    const list = agents();
    const a = list.find((x) => f?.pane && x.pane === f.pane) ?? list.find((x) => x.address === f?.terminal) ?? list.find((x) => x.focused);
    if (a) {
      const map = { ...(shared("retropet.digimon") ?? {}) };
      map[a.address] = ((map[a.address] ?? 0) + 1) % 1000;
      setShared("retropet.digimon", map);
    }
    cx.spawn(async () => closeOverlay(props()?.overlay));
  }

  render() {
    return div();
  }
}
