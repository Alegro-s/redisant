const stack = () => document.getElementById("toast-stack");

export function toast(message, ms = 3000) {
  const el = document.createElement("div");
  el.className = "toast";
  el.textContent = message;
  stack()?.appendChild(el);
  setTimeout(() => el.remove(), ms);
}
