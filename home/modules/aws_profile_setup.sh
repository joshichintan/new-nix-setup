#!/usr/bin/env bash
set -euo pipefail

# First-time SSO setup + transactional sync of profiles
# - If no SSO sessions exist, run the AWS wizard to add one
# - Login for each SSO session
# - Generate/refresh profiles for all accounts+roles (atomic & idempotent)

require() { command -v "$1" >/dev/null 2>&1 || { echo "Missing dependency: $1" >&2; exit 1; }; }
require aws
require jq
require python3

CONFIG="${HOME}/.aws/config"
mkdir -p "$(dirname "$CONFIG")"
touch "$CONFIG"

# -------- helper: list sso-session names from ~/.aws/config --------
list_sessions() {
  python3 - <<'PY'
import os,re,sys
cfg=os.path.expanduser("~/.aws/config")
if not os.path.exists(cfg):
  sys.exit(0)
sec=None
seen=[]
with open(cfg,"r",encoding="utf-8") as f:
  for line in f:
    line=line.strip()
    if not line or line.startswith(("#",";")): continue
    m=re.match(r'^\[(.+?)\]$', line)
    if m:
      sec=m.group(1)
      if sec.startswith("sso-session "):
        seen.append(sec[len("sso-session "):])
    else:
      continue
print("\n".join(seen))
PY
}

# -------- interactive: ensure at least one SSO session exists --------
ensure_session() {
  local sessions
  sessions="$(list_sessions || true)"
  if [[ -z "$sessions" ]]; then
    echo "No SSO sessions found in ~/.aws/config."
    echo "Launching AWS SSO configuration wizard..."
    echo
    aws configure sso --no-cli-auto-prompt
    echo
    sessions="$(list_sessions || true)"
    if [[ -z "$sessions" ]]; then
      echo "No SSO sessions were created. Re-run and complete the wizard." >&2
      exit 1
    fi
  fi
}

# -------- helper: get latest valid token for SSO session --------
latest_token_for() { # startUrl region -> token or empty
  local url="$1" reg="$2"
  jq -r --arg url "$url" --arg reg "$reg" '
    try (
      select(.accessToken and .expiresAt and .startUrl==$url and .region==$reg)
      | select((.expiresAt | fromdateiso8601) > now)
      | [.expiresAt, .accessToken] | @tsv
    ) catch empty
  ' ${HOME}/.aws/sso/cache/*.json 2>/dev/null | sort -r | head -n1 | cut -f2
}

# -------- login to each SSO session --------
login_all_sessions() {
  local s
  while IFS= read -r s; do
    [[ -z "$s" ]] && continue
    
    # Get session details
    local SURL SREG
    SURL=$(python3 - <<PY
import os,re,json,sys
sname = "$s"
cfg=os.path.expanduser("~/.aws/config")
if os.path.exists(cfg):
  with open(cfg,"r",encoding="utf-8") as f:
    for line in f:
      line=line.strip()
      if line == f"[sso-session {sname}]":
        for line in f:
          line=line.strip()
          if line.startswith("sso_start_url"):
            print(line.split("=",1)[1].strip())
            break
          elif line.startswith("["):
            break
PY
)
    SREG=$(python3 - <<PY
import os,re,json,sys
sname = "$s"
cfg=os.path.expanduser("~/.aws/config")
if os.path.exists(cfg):
  with open(cfg,"r",encoding="utf-8") as f:
    for line in f:
      line=line.strip()
      if line == f"[sso-session {sname}]":
        for line in f:
          line=line.strip()
          if line.startswith("sso_region"):
            print(line.split("=",1)[1].strip())
            break
          elif line.startswith("["):
            break
PY
)
    
    # Check if token is still valid
    local TOKEN
    TOKEN="$(latest_token_for "$SURL" "$SREG" 2>/dev/null || true)"
    
    if [[ -n "${TOKEN:-}" ]]; then
      echo "✓ Valid token found for SSO session: $s (skipping login)"
    else
      echo "Logging in for SSO session: $s"
      aws sso login --sso-session "$s"
    fi
  done < <(list_sessions)
}

# ================== transactional profile generator (our previous script) ==================
sync_profiles() {
  local BASE_CONFIG="${HOME}/.aws/config"
  local CACHE_GLOB="${HOME}/.aws/sso/cache/*.json"

  mkdir -p "$(dirname "$BASE_CONFIG")"
  touch "$BASE_CONFIG"

  clean_name() { tr '[:upper:]' '[:lower:]' | tr ' ' '_' | tr -cd 'a-z0-9_' | cut -c1-20; }

  profile_block_exists() { local name="$1";
    awk -v p="$name" '$0 ~ "^\\[profile[[:space:]]+"p"\\]" {found=1} END{exit(found?0:1)}' "$BASE_CONFIG"; }

  profile_block_matches() { # name acc role sso region
    local name="$1" acc="$2" role="$3" sso="$4" reg="$5"
    awk -v p="$name" -v a="$acc" -v r="$role" -v s="$sso" -v g="$reg" '
      BEGIN{hit=0;ok=0}
      $0 ~ "^\\[profile[[:space:]]+"p"\\]" {hit=1; next}
      hit && /^sso_account_id[[:space:]]*=/ {split($0,f,"="); gsub(/^[ \t]+|[ \t]+$/,"",f[2]); if(f[2]==a) ok++}
      hit && /^sso_role_name[[:space:]]*=/  {split($0,f,"="); gsub(/^[ \t]+|[ \t]+$/,"",f[2]); if(f[2]==r) ok++}
      hit && /^sso_session[[:space:]]*=/    {split($0,f,"="); gsub(/^[ \t]+|[ \t]+$/,"",f[2]); if(f[2]==s) ok++}
      hit && /^region[[:space:]]*=/         {split($0,f,"="); gsub(/^[ \t]+|[ \t]+$/,"",f[2]); if(f[2]==g) ok++}
      hit && /^\[/ {hit=0}
      END {exit( (ok>=4) ? 0 : 1 )}
    ' "$BASE_CONFIG"
  }

  replace_profile_block() { # name; stdin=new block
    local name="$1" TMP
    TMP="$(mktemp)"
    awk -v p="$name" '
      BEGIN{drop=0}
      {
        if ($0 ~ "^\\[profile[[:space:]]+"p"\\]") {drop=1; next}
        if (drop && $0 ~ /^\[/) {drop=0}
        if (!drop) print $0
      }
    ' "$BASE_CONFIG" > "$TMP"
    printf "\n" >> "$TMP"
    cat >> "$TMP"
    if AWS_CONFIG_FILE="$TMP" aws configure list-profiles >/dev/null 2>&1; then
      mv "$TMP" "$BASE_CONFIG"
      echo "✓ Updated: [$name]"
    else
      rm -f "$TMP"
      echo "✗ Validation failed for [$name]; no changes written." >&2
      return 1
    fi
  }


  # Discover sso-sessions
  local SESS_JSON
  SESS_JSON="$(
    python3 - <<'PY'
import os,re,json
cfg=os.path.expanduser("~/.aws/config")
sessions={}
sec=None
if os.path.exists(cfg):
  with open(cfg,"r",encoding="utf-8") as f:
    for line in f:
      line=line.strip()
      if not line or line.startswith(("#",";")): continue
      m=re.match(r'^\[(.+?)\]$', line)
      if m:
        sec=m.group(1)
      elif "=" in line and sec and sec.startswith("sso-session "):
        k,v=[p.strip() for p in line.split("=",1)]
        k=k.replace("-","_")
        sessions.setdefault(sec[len("sso-session "):],{})[k]=v
out=[]
for sname,d in sessions.items():
  out.append({"sso_session":sname,"sso_start_url":d.get("sso_start_url"),"sso_region":d.get("sso_region")})
print(json.dumps(out))
PY
  )"

  # Iterate sessions
  echo "$SESS_JSON" | jq -c '.[]' | while read -r S; do
    local SNAME SURL SREG TOKEN
    SNAME=$(jq -r '.sso_session'  <<<"$S")
    SURL=$(jq -r '.sso_start_url' <<<"$S")
    SREG=$(jq -r '.sso_region'    <<<"$S")

    [[ -z "$SURL" || -z "$SREG" ]] && { echo "Skip '$SNAME' (missing start_url/region)"; continue; }

    TOKEN="$(latest_token_for "$SURL" "$SREG" || true)"
    if [[ -z "${TOKEN:-}" ]]; then
      echo "No valid token for session '$SNAME'. Try: aws sso login --sso-session $SNAME" >&2
      continue
    fi

    local ACCOUNTS_JSON
    ACCOUNTS_JSON="$(aws sso list-accounts --region "$SREG" --access-token "$TOKEN" --output json)"
    jq -r '.accountList[] | [.accountId,.accountName] | @tsv' <<<"$ACCOUNTS_JSON" \
    | while IFS=$'\t' read -r ACC_ID ACC_NAME; do
        local ROLES_JSON
        ROLES_JSON="$(aws sso list-account-roles --region "$SREG" --access-token "$TOKEN" --account-id "$ACC_ID" --output json)"
        jq -r '.roleList[].roleName' <<<"$ROLES_JSON" \
        | while read -r ROLE; do
            local PNAME SNAME_CLEAN ACC_CLEAN ROLE_CLEAN
            SNAME_CLEAN="$(printf '%s' "$SNAME"    | clean_name)"
            ACC_CLEAN="$( printf '%s' "$ACC_NAME" | clean_name)"
            ROLE_CLEAN="$(printf '%s' "$ROLE"     | clean_name)"
            PNAME="${SNAME_CLEAN}_${ACC_CLEAN}_${ROLE_CLEAN}"

            if profile_block_exists "$PNAME" && profile_block_matches "$PNAME" "$ACC_ID" "$ROLE" "$SNAME" "$SREG"; then
              echo "• Skip (up-to-date): [$PNAME]"
              continue
            fi

            cat <<EOF | replace_profile_block "$PNAME"

[profile ${PNAME}]
sso_session    = ${SNAME}
sso_account_id = ${ACC_ID}
sso_role_name  = ${ROLE}
region         = ${SREG}
output         = json
EOF
        done
      done
  done

  echo "Sync complete."
}

# ================== main ==================
ensure_session
login_all_sessions
sync_profiles

