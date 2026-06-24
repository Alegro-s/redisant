import { pullDashboard, blockUser, unblockUser } from "../api/client.js";
import { getState } from "../core/state.js";

export function runCommand(line, ctx) {
  const raw = line.trim();
  if (!raw) return;
  const [cmd, ...rest] = raw.split(/\s+/);
  const arg = rest.join(" ");

  switch (cmd.toLowerCase()) {
    case "справка":
    case "help":
      break;
    case "обновить":
    case "refresh":
      ctx.refresh();
      ctx.log("обновление…");
      break;
    case "блок":
    case "block":
      if (!arg) break;
      ctx.blockPrompt(arg.split(/\s+/)[0], rest.slice(1).join(" ") || "ручная блокировка");
      break;
    case "разблок":
    case "unblock":
      if (!arg) break;
      ctx.unblock(arg.split(/\s+/)[0]);
      break;
    case "алерты":
      ctx.navigate("alerts");
      ctx.log(`алертов: ${getState().alerts.length}`);
      break;
    default:
      break;
  }
}

export async function execBlock(id, reason, ctx) {
  try {
    await blockUser(id, reason);
    await pullDashboard();
    ctx.log(`заблокирован: ${id}`);
    ctx.toast("Пользователь заблокирован");
  } catch (e) {
    ctx.log(e.message || "ошибка блокировки");
    ctx.toast("Ошибка блокировки");
  }
}

export async function execUnblock(id, ctx) {
  try {
    await unblockUser(id);
    await pullDashboard();
    ctx.log(`разблокирован: ${id}`);
    ctx.toast("Пользователь разблокирован");
  } catch (e) {
    ctx.log(e.message || "ошибка");
    ctx.toast("Ошибка разблокировки");
  }
}
