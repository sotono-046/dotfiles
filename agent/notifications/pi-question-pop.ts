import { execFile } from "node:child_process";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

function inheritedOrcaOwner(): boolean {
  for (const name of ["ORCA_PI_STATUS_OWNED", "ORCA_PI_TITLE_MARKER_OWNED"]) {
    const owner = process.env[name];
    if (!owner || owner === String(process.pid)) continue;
    const pid = Number(owner);
    if (!Number.isSafeInteger(pid) || pid < 1) continue;
    try {
      process.kill(pid, 0);
      return true;
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code !== "ESRCH") return true;
    }
  }
  return false;
}

function playPop(): void {
  if (["0", "false", "off", "no"].includes((process.env.AGENT_QUESTION_SOUND ?? "on").toLowerCase())) return;
  if (inheritedOrcaOwner()) return;
  execFile("/usr/bin/afplay", ["/System/Library/Sounds/Pop.aiff"], { timeout: 3000, windowsHide: true }, () => {});
}

export default function (pi: ExtensionAPI): void {
  let pending = false;
  pi.on("session_start", () => { pending = false; });
  pi.on("ui_prompt_start", (_event, ctx) => {
    if (!ctx.hasUI || ctx.isIdle() || pending) return;
    pending = true;
    playPop();
  });
  pi.on("ui_prompt_end", () => { pending = false; });
}
