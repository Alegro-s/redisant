
set -euo pipefail

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "Запустите от root: sudo bash $0"
  exit 1
fi

read -r -s -p "Новый пароль root: " P1
echo ""
read -r -s -p "Повторите пароль: " P2
echo ""

if [[ -z "$P1" ]] || [[ ${#P1} -lt 12 ]]; then
  echo "Пароль пустой или короче 12 символов — выберите более длинный."
  exit 1
fi

if [[ "$P1" != "$P2" ]]; then
  echo "Пароли не совпадают."
  exit 1
fi

echo "root:$P1" | chpasswd
echo "[NEXUS] Пароль root обновлён. Сохраните его в менеджере паролей."
