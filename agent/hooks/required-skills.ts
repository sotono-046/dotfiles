import { execFileSync } from "node:child_process";
import { realpathSync } from "node:fs";
import { fileURLToPath } from "node:url";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

const customType = "dotfiles-required-skills";
const script = realpathSync(fileURLToPath(import.meta.url)).replace(/\.ts$/, ".py");
type Bundle = { digest: string; text: string };

function loadBundle(): Bundle {
  const output = execFileSync("python3", [script, "bundle", "--client", "pi"], {
    encoding: "utf8",
    maxBuffer: 2 * 1024 * 1024,
    timeout: 15000,
    stdio: ["ignore", "pipe", "pipe"],
  });
  const bundle = JSON.parse(output);
  if (typeof bundle.text !== "string" || typeof bundle.digest !== "string" || !bundle.text || bundle.text.length > 128000) {
    throw new Error("必須スキル全文の形式または長さが不正です");
  }
  return bundle;
}

function stop(ctx: ExtensionContext, error: unknown): string {
  const reason = `required-skills: ${String(error)}。必須スキル全文を読み込めるまで停止します。`;
  ctx.abort();
  if (ctx.hasUI) ctx.ui.notify(reason, "error");
  return reason;
}

export default function requiredSkills(pi: ExtensionAPI) {
  let lastDigest: string | undefined;

  pi.on("context", async (event, ctx) => {
    try {
      const bundle = loadBundle();
      lastDigest = bundle.digest;
      return {
        messages: [
          ...event.messages.filter((message) => !(message.role === "custom" && message.customType === customType)),
          { role: "custom", customType, content: bundle.text, display: false, timestamp: Date.now() },
        ],
      };
    } catch (error) {
      lastDigest = undefined;
      throw new Error(stop(ctx, error));
    }
  });

  pi.on("tool_call", async (_event, ctx) => {
    try {
      if (loadBundle().digest !== lastDigest) {
        return { block: true, reason: "必須スキルが更新されました。次の応答で全文を読み込んでから再試行してください。" };
      }
    } catch (error) {
      lastDigest = undefined;
      return { block: true, reason: stop(ctx, error) };
    }
  });
}
