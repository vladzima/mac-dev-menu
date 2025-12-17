#!/usr/bin/env bash
set -euo pipefail

PROC_RE='(node|bun|deno)'
NGROK_API_URL="${NGROK_API_URL:-http://127.0.0.1:4040/api/tunnels}"
NGROK_WEB_URL="${NGROK_WEB_URL:-http://127.0.0.1:4040}"

to_int() {
  local v="${1:-}"
  v="$(printf "%s" "$v" | tr -cd '0-9')"
  [[ -z "$v" ]] && v="0"
  printf "%s" "$v"
}

entries="$(
  lsof -nP -iTCP -sTCP:LISTEN 2>/dev/null \
  | awk -v re="$PROC_RE" '
      NR>1 && $1 ~ re {
        pid=$2; name=$9;
        port=name;
        sub(/^.*:/,"",port);
        sub(/ .*$/,"",port);
        key=pid ":" port;
        if (!seen[key]++) print pid "\t" port;
      }
    ' \
  | sort -t$'\t' -k2,2n
)"

ngrok_pid="$(
  lsof -nP -iTCP:4040 -sTCP:LISTEN 2>/dev/null \
  | awk 'NR==2 {print $2}' || true
)"

ngrok_present="0"
if [[ -n "${ngrok_pid// }" ]]; then
  ngrok_present="1"
fi

ngrok_json="$(curl -fsS --connect-timeout 0.2 --max-time 1 "$NGROK_API_URL" 2>/dev/null || true)"
if [[ -z "${ngrok_json// }" && "$ngrok_present" == "1" ]]; then
  ngrok_json="$(curl -fsS --connect-timeout 0.5 --max-time 2 "$NGROK_API_URL" 2>/dev/null || true)"
fi

ngrok_tsv=""
if [[ -n "${ngrok_json// }" ]] && command -v python3 >/dev/null 2>&1; then
  ngrok_tsv="$(python3 -c 'import json,sys,re
def local_url(addr):
    if not addr: return ""
    a=str(addr).strip()
    if a.startswith(("http://","https://")): return a
    if a.startswith(("localhost:","127.0.0.1:")): return "http://" + a
    return a
def extract_port(addr):
    if not addr: return ""
    a=str(addr).strip()
    a=re.sub(r"^https?://","",a)
    m=re.search(r":(\d+)",a)
    return m.group(1) if m else ""
try:
    d=json.load(sys.stdin)
except Exception:
    sys.exit(0)
for t in (d.get("tunnels") or []):
    pub=(t.get("public_url") or "").strip()
    addr=((t.get("config") or {}).get("addr") or "").strip()
    port=extract_port(addr)
    loc=local_url(addr)
    if pub and port:
        print(f"{port}\t{loc}\t{pub}\t{addr}")
' <<<"$ngrok_json" 2>/dev/null || true)"
fi

ngrok_count="$(printf "%s\n" "$ngrok_tsv" | sed '/^$/d' | wc -l | tr -d ' ' || true)"
ngrok_count="$(to_int "$ngrok_count")"
if (( ngrok_count == 0 )) && [[ "$ngrok_present" == "1" ]] && [[ -z "${ngrok_json// }" ]]; then
  ngrok_count="1"
fi

dev_count="$(printf "%s\n" "$entries" | sed '/^$/d' | wc -l | tr -d ' ' || true)"
dev_count="$(to_int "$dev_count")"

total="$((dev_count + ngrok_count))"
echo "D:$total"
echo "---"

detect_framework() {
  local pid="$1"
  local cwd="$2"
  local cmdline=""
  local pkg="$cwd/package.json"
  local fw=""

  cmdline="$(ps -p "$pid" -o command= 2>/dev/null | sed 's/^[[:space:]]*//' || true)"

  if printf "%s" "$cmdline" | grep -Eqi '(^|[ /])next([ /]|$)'; then
    fw="next"
  elif printf "%s" "$cmdline" | grep -Eqi '(^|[ /])vite([ /]|$)'; then
    fw="vite"
  elif printf "%s" "$cmdline" | grep -Eqi 'react-scripts([ /]|$)'; then
    fw="cra"
  elif printf "%s" "$cmdline" | grep -Eqi 'webpack-dev-server([ /]|$)'; then
    fw="webpack"
  elif printf "%s" "$cmdline" | grep -Eqi '(^|[ /])parcel([ /]|$)'; then
    fw="parcel"
  elif printf "%s" "$cmdline" | grep -Eqi '(^|[ /])astro([ /]|$)'; then
    fw="astro"
  elif printf "%s" "$cmdline" | grep -Eqi '(^|[ /])nuxt([ /]|$)'; then
    fw="nuxt"
  elif printf "%s" "$cmdline" | grep -Eqi '(^|[ /])remix([ /]|$)'; then
    fw="remix"
  fi

  if [[ -n "$fw" || ! -f "$pkg" ]]; then
    printf "%s" "$fw"
    return 0
  fi

  if command -v python3 >/dev/null 2>&1; then
    fw="$(python3 - "$pkg" <<'PY'
import json, sys
p = sys.argv[1]
try:
    d = json.load(open(p, "r", encoding="utf-8"))
except Exception:
    print("")
    raise SystemExit(0)

def has_dep(name):
    for k in ("dependencies", "devDependencies"):
        if isinstance(d.get(k), dict) and name in d[k]:
            return True
    return False

scripts = d.get("scripts") if isinstance(d.get("scripts"), dict) else {}
dev = (scripts.get("dev") or "")
dev_l = str(dev).lower()

fw = ""
if "next" in dev_l or has_dep("next"):
    fw = "next"
elif "vite" in dev_l or has_dep("vite"):
    fw = "vite"
elif "react-scripts" in dev_l or has_dep("react-scripts"):
    fw = "cra"
elif "webpack-dev-server" in dev_l or has_dep("webpack-dev-server"):
    fw = "webpack"
elif "parcel" in dev_l or has_dep("parcel"):
    fw = "parcel"
elif "astro" in dev_l or has_dep("astro"):
    fw = "astro"
elif "nuxt" in dev_l or has_dep("nuxt"):
    fw = "nuxt"
elif "remix" in dev_l or has_dep("@remix-run/dev") or has_dep("remix"):
    fw = "remix"

print(fw)
PY
)"
  fi

  printf "%s" "$fw"
}

get_app_name() {
  local cwd="$1"
  local pkg="$cwd/package.json"
  local name=""

  if [[ -f "$pkg" ]] && command -v python3 >/dev/null 2>&1; then
    name="$(python3 - "$pkg" <<'PY'
import json, sys
p = sys.argv[1]
try:
    d = json.load(open(p, "r", encoding="utf-8"))
    print(str(d.get("name") or ""))
except Exception:
    print("")
PY
)"
  fi

  if [[ -n "$name" ]]; then
    printf "%s" "$name"
    return 0
  fi

  if [[ "$cwd" == *"/projects/"* ]]; then
    printf "%s" "$cwd" | sed -E 's|^.*\/projects\/([^\/]+).*|\1|'
  else
    basename "$cwd"
  fi
}

if [[ -n "${entries// }" ]]; then
  printf "%s\n" "$entries" \
  | while IFS=$'\t' read -r pid port; do
      cwd="$(
        lsof -a -p "$pid" -d cwd -Fn 2>/dev/null \
        | sed -n 's/^n//p' \
        | head -n 1 || true
      )"

      if [[ -z "$cwd" ]]; then
        app="unknown"
        fw=""
        cwd="(cwd unknown)"
      else
        app="$(get_app_name "$cwd")"
        fw="$(detect_framework "$pid" "$cwd")"
      fi

      if [[ -n "$fw" ]]; then
        title="$port — $app ($fw)"
      else
        title="$port — $app"
      fi

      echo "$title | href=http://localhost:$port"
      echo "--$cwd"
      echo "--Stop | bash=/bin/kill param1=-TERM param2=$pid terminal=false refresh=true"
    done
else
  echo "No dev servers"
fi

if [[ -n "${ngrok_tsv// }" ]]; then
  printf "%s\n" "$ngrok_tsv" \
  | while IFS=$'\t' read -r port local pub addr; do
      echo "$port — ngrok | href=http://localhost:$port"
      echo "--$pub | href=$pub"
      if [[ -n "${local// }" ]]; then
        echo "--Open local | href=$local"
      fi
      echo "--Web Interface | href=$NGROK_WEB_URL"
      if [[ -n "${ngrok_pid// }" ]]; then
        echo "--Stop ngrok | bash=/bin/kill param1=-TERM param2=$ngrok_pid terminal=false refresh=true"
      fi
    done
elif [[ "$ngrok_present" == "1" ]]; then
  echo "ngrok | href=$NGROK_WEB_URL"
fi
