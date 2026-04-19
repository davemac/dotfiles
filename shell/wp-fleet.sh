# WordPress Fleet Operations
#
# Multi-site bulk operations across every WordPress site registered as an
# MCP server in Claude Code. Iterates the wordpress-* entries from
# ~/.claude.json (same source of truth as wp_mcp_list_sites) and applies
# per-site operations across the fleet, aggregating results. Failures on
# individual sites do not abort the run — each is logged and the loop
# continues.
#
# ============================================================================
# FUNCTION INDEX
# ============================================================================
#
# Fleet Operations:
# - wp_fleet_update         - Plugin/theme/core updates across all registered sites
# - wp_fleet_db_optimise    - Safe DB cleanup across all registered sites
#
# Shared flags:
#   --dry-run, -n        Preview what would happen; do not execute
#   --yes, -y            Skip the interactive confirmation prompt
#   --json               Emit machine-readable JSON (suppresses all decorative output)
#   --only=<pattern>     Glob filter over server names (matches "colacnew" or
#                        "wordpress-colacnew"; supports * and ?)
#   --exclude=<pattern>  Inverse glob filter
#   --help, -h           Show per-function help
#
# ============================================================================
# DESIGN DECISIONS
# ============================================================================
#
# 1) Remote (http-proxy) sites are skipped in v1.
#    The MCP registry stores HTTP credentials for diagnostics, not the SSH
#    alias needed to run wp-cli remotely. v1 prints a clear "skipping remote
#    site — fleet ops require local wp-cli access" for each http-proxy entry
#    and records it in the JSON summary as status:"skipped".
#    v2 plan: add WP_FLEET_SSH_MAP to .dotfiles-config (associative array:
#    wordpress-<name> -> ssh-alias) and dispatch via SSH.
#
# 2) wp_fleet_db_optimise runs a SAFE SUBSET of wp_db_optimise's operations.
#    The single-site wp_db_optimise rewrites wp-config constants and
#    deactivates production plugins (jetpack, akismet, wp-seopress, ...) —
#    appropriate for a local dev box, dangerous across a fleet that may
#    include production. The fleet version runs only read/cleanup queries:
#    expired transients, orphaned postmeta, stale auto-drafts, stale edit
#    locks, and `wp db optimize`. No plugin state changes, no config rewrites.
#
# 3) Per-site invocation uses wp-cli with explicit --path= (and --url= when
#    the MCP entry has one) rather than calling the existing `updatem` alias
#    or `wp_db_optimise`. Both of those assume `cd $site_root` and operate
#    in cwd; running them in a fleet loop is fragile. The fleet version
#    reconstructs the wp-cli arguments directly from the MCP entry, the same
#    way wp_mcp_list_sites does for display.
#
# 4) JSON output is a stable contract for the future local-only web app
#    dashboard. When --json is set, all decorative output is suppressed and
#    a single JSON document is emitted at the end. Top-level shape:
#      {
#        "operation": "wp_fleet_update" | "wp_fleet_db_optimise",
#        "started_at":  "<ISO8601 UTC>",
#        "finished_at": "<ISO8601 UTC>",
#        "dry_run": <bool>,
#        "sites": [
#          {
#            "name":      "wordpress-<site>",
#            "transport": "stdio-local" | "http-proxy",
#            "path":      "<wp-path or null>",
#            "url":       "<subsite-url or null>",
#            "status":    "success" | "failed" | "skipped" | "dry-run",
#            "details":   { ...operation-specific keys... },
#            "errors":    [ "<message>", ... ]
#          }
#        ],
#        "summary": { "total": N, "succeeded": N, "failed": N, "skipped": N }
#      }
#    Operation-specific "details" keys:
#      wp_fleet_update       plugin_updates (int), theme_updates (int), core_update (bool)
#      wp_fleet_db_optimise  transients_expired, orphaned_postmeta, auto_drafts,
#                            edit_locks (all ints); db_optimised (bool)
#
# ============================================================================

# Internal: error out if jq is not on PATH. Shared with wp-mcp.sh usage.
_wp_fleet_require_jq() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq is required (brew install jq)"
    return 1
  fi
}

# Internal: UTC ISO8601 timestamp.
_wp_fleet_now_utc() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# Internal: read every wordpress-* MCP server from ~/.claude.json as TSV.
# Columns (tab-separated): name, transport, path, url, scope
#   transport = stdio-local | http-proxy | unknown
#   path/url  = wp-cli --path= / --url= values for stdio-local entries;
#               WP_API_URL for http-proxy entries; "" otherwise
#   scope     = "user" or "project:<project-path>"
# Sorted by name for stable output.
_wp_fleet_collect_sites() {
  local config="$HOME/.claude.json"
  if [[ ! -f "$config" ]]; then
    echo "Error: $config not found — Claude Code may not be installed/configured" >&2
    return 1
  fi

  jq -r '
    def transport(s):
      if (s.command == "npx") and ((s.args // []) | any(test("mcp-wordpress-remote")))
        then "http-proxy"
      elif s.command == "wp"
        then "stdio-local"
      else (s.type // "unknown") end;

    def get_arg(s; prefix):
      [(s.args // [])[]? | select(startswith(prefix)) | sub("^" + prefix; "")][0] // "";

    def site_path(s):
      if transport(s) == "stdio-local" then get_arg(s; "--path=") else "" end;

    def site_url(s):
      if transport(s) == "stdio-local" then get_arg(s; "--url=")
      elif transport(s) == "http-proxy" then (s.env.WP_API_URL // "")
      else "" end;

    def collect(scope_label; servers):
      (servers // {}) | to_entries[]
      | select(.key | startswith("wordpress-"))
      | [.key, transport(.value), site_path(.value), site_url(.value), scope_label]
      | @tsv;

    [
      collect("user"; .mcpServers),
      ((.projects // {}) | to_entries[] | .key as $p | collect("project:" + $p; .value.mcpServers))
    ] | sort | .[]
  ' "$config"
}

# Internal: test whether $name matches $pattern as a glob. The pattern is
# tried against both the full name and the name with "wordpress-" stripped,
# so --only=colacnew works as well as --only=wordpress-colacnew.
# Returns 0 (match) or 1 (no match).
_wp_fleet_name_matches() {
  local name="$1" pattern="$2"
  [[ -z "$pattern" ]] && return 0
  local bare="${name#wordpress-}"
  if [[ "$name" == ${~pattern} || "$bare" == ${~pattern} ]]; then
    return 0
  fi
  return 1
}

# Internal: build a JSON object describing a per-site result. All args are
# positional to keep the call sites short.
# Args: name transport wp_path url site_status details_json errors_json
# Note: wp_path (not "path") and site_status (not "status") — "path" and
# "status" are both special parameters in zsh ($path is tied to $PATH, and
# $status is read-only, aliased to $?). Using them as local names triggers
# "read-only variable" errors and corrupts the shell's local state.
_wp_fleet_site_json() {
  local name="$1" transport="$2" wp_path="$3" url="$4" site_status="$5"
  local details="${6:-{\}}" errors="${7:-[]}"
  jq -nc \
    --arg name "$name" \
    --arg transport "$transport" \
    --arg wp_path "$wp_path" \
    --arg url "$url" \
    --arg site_status "$site_status" \
    --argjson details "$details" \
    --argjson errors "$errors" \
    '{
      name: $name,
      transport: $transport,
      path: (if $wp_path == "" then null else $wp_path end),
      url:  (if $url  == "" then null else $url  end),
      status: $site_status,
      details: $details,
      errors: $errors
    }'
}

# Internal: per-site op for wp_fleet_update.
# Args: dry_run path url json_mode
# Stdout: the "details" JSON object plus an errors array on a second line
#         (NDJSON: two lines, details then errors).
# Stderr: human-readable progress lines (suppressed by caller when --json).
# Returns: 0 success, 1 failure (still emits result to stdout for aggregation).
_wp_fleet_update_one() {
  # Some shells have TYPESET_SILENT unset (oh-my-zsh, prezto, sh emulation),
  # which makes `local foo` with no value auto-print `foo=''` to stdout and
  # corrupts --json output. local_options restores the caller's state on exit.
  setopt local_options typeset_silent
  local dry_run="$1" wp_path="$2" url="$3"
  local -a wp_args
  wp_args=( "--path=$wp_path" )
  [[ -n "$url" ]] && wp_args+=( "--url=$url" )

  local plugin_updates=0 theme_updates=0 core_updates=0
  local -a errors
  errors=()

  # Count available updates (used for both dry-run preview and real-run summary).
  plugin_updates=$(wp "${wp_args[@]}" plugin list --update=available --format=count 2>/dev/null || echo 0)
  theme_updates=$(wp "${wp_args[@]}" theme list --update=available --format=count 2>/dev/null || echo 0)
  # wp core check-update: any output = update pending. Use jq on --format=json
  # to avoid a grep/wc dependency when the shell's command hash is stale.
  local core_json
  core_json=$(wp "${wp_args[@]}" core check-update --format=json 2>/dev/null)
  core_updates=0
  if [[ -n "$core_json" && "$core_json" != "null" && "$core_json" != "[]" ]]; then
    core_updates=$(jq 'length' <<< "$core_json" 2>/dev/null || echo 0)
  fi
  core_updates=${core_updates:-0}

  echo >&2 "      plugin updates pending: $plugin_updates"
  echo >&2 "      theme updates pending:  $theme_updates"
  echo >&2 "      core update pending:    $([[ $core_updates -gt 0 ]] && echo yes || echo no)"

  local failed=0
  if [[ "$dry_run" != "true" ]]; then
    echo >&2 "      updating plugins..."
    if ! wp "${wp_args[@]}" plugin update --all >&2; then
      errors+=( "plugin update failed" )
      failed=1
    fi
    echo >&2 "      updating themes..."
    if ! wp "${wp_args[@]}" theme update --all >&2; then
      errors+=( "theme update failed" )
      failed=1
    fi
    if [[ $core_updates -gt 0 ]]; then
      echo >&2 "      updating core..."
      if ! wp "${wp_args[@]}" core update >&2; then
        errors+=( "core update failed" )
        failed=1
      fi
    fi
  fi

  local core_update_bool=false
  [[ $core_updates -gt 0 ]] && core_update_bool=true

  local details
  details=$(jq -nc \
    --argjson plugin_updates "${plugin_updates:-0}" \
    --argjson theme_updates "${theme_updates:-0}" \
    --argjson core_update "$core_update_bool" \
    '{plugin_updates: $plugin_updates, theme_updates: $theme_updates, core_update: $core_update}')

  local errors_json
  if (( ${#errors[@]} == 0 )); then
    errors_json='[]'
  else
    errors_json=$(printf '%s\n' "${errors[@]}" | jq -R . | jq -sc .)
  fi

  printf '%s\n' "$details"
  printf '%s\n' "$errors_json"
  return $failed
}

# Internal: per-site op for wp_fleet_db_optimise.
# Args: dry_run path url
# Stdout: NDJSON — details line, then errors line.
# Stderr: human progress.
# Returns: 0 success, 1 failure.
_wp_fleet_db_optimise_one() {
  setopt local_options typeset_silent
  local dry_run="$1" wp_path="$2" url="$3"
  local -a wp_args
  wp_args=( "--path=$wp_path" )
  [[ -n "$url" ]] && wp_args+=( "--url=$url" )

  local prefix
  prefix=$(wp "${wp_args[@]}" db prefix 2>/dev/null)
  prefix="${prefix:-wp_}"

  # Count eligible rows for each cleanup — used for dry-run preview and summary.
  local -a errors
  errors=()

  local q_trans="SELECT COUNT(*) FROM ${prefix}options WHERE option_name LIKE '_transient_timeout_%' AND option_value < UNIX_TIMESTAMP();"
  local q_orphan="SELECT COUNT(*) FROM ${prefix}postmeta pm LEFT JOIN ${prefix}posts p ON p.ID = pm.post_id WHERE p.ID IS NULL;"
  local q_drafts="SELECT COUNT(*) FROM ${prefix}posts WHERE post_status = 'auto-draft' AND post_date < DATE_SUB(NOW(), INTERVAL 7 DAY);"
  local q_locks="SELECT COUNT(*) FROM ${prefix}postmeta WHERE meta_key = '_edit_lock' AND meta_value < UNIX_TIMESTAMP(DATE_SUB(NOW(), INTERVAL 7 DAY));"

  local transients orphaned drafts locks
  transients=$(wp "${wp_args[@]}" db query "$q_trans" --skip-column-names --silent 2>/dev/null | tr -d '[:space:]')
  orphaned=$(wp "${wp_args[@]}" db query "$q_orphan" --skip-column-names --silent 2>/dev/null | tr -d '[:space:]')
  drafts=$(wp "${wp_args[@]}" db query "$q_drafts" --skip-column-names --silent 2>/dev/null | tr -d '[:space:]')
  locks=$(wp "${wp_args[@]}" db query "$q_locks" --skip-column-names --silent 2>/dev/null | tr -d '[:space:]')
  transients="${transients:-0}"
  orphaned="${orphaned:-0}"
  drafts="${drafts:-0}"
  locks="${locks:-0}"

  echo >&2 "      expired transients:  $transients"
  echo >&2 "      orphaned postmeta:   $orphaned"
  echo >&2 "      stale auto-drafts:   $drafts"
  echo >&2 "      stale edit locks:    $locks"

  local failed=0
  local db_optimised=false

  if [[ "$dry_run" != "true" ]]; then
    echo >&2 "      deleting expired transients..."
    if ! wp "${wp_args[@]}" transient delete --expired >&2; then
      errors+=( "transient delete --expired failed" )
      failed=1
    fi

    if [[ "$orphaned" != "0" ]]; then
      echo >&2 "      removing orphaned postmeta..."
      if ! wp "${wp_args[@]}" db query "DELETE pm FROM ${prefix}postmeta pm LEFT JOIN ${prefix}posts p ON p.ID = pm.post_id WHERE p.ID IS NULL;" >/dev/null 2>&1; then
        errors+=( "orphaned postmeta delete failed" )
        failed=1
      fi
    fi

    if [[ "$drafts" != "0" ]]; then
      echo >&2 "      removing stale auto-drafts..."
      if ! wp "${wp_args[@]}" db query "DELETE FROM ${prefix}posts WHERE post_status = 'auto-draft' AND post_date < DATE_SUB(NOW(), INTERVAL 7 DAY);" >/dev/null 2>&1; then
        errors+=( "auto-draft delete failed" )
        failed=1
      fi
    fi

    if [[ "$locks" != "0" ]]; then
      echo >&2 "      removing stale edit locks..."
      if ! wp "${wp_args[@]}" db query "DELETE FROM ${prefix}postmeta WHERE meta_key = '_edit_lock' AND meta_value < UNIX_TIMESTAMP(DATE_SUB(NOW(), INTERVAL 7 DAY));" >/dev/null 2>&1; then
        errors+=( "edit-lock delete failed" )
        failed=1
      fi
    fi

    echo >&2 "      running wp db optimize..."
    if wp "${wp_args[@]}" db optimize >/dev/null 2>&1; then
      db_optimised=true
    else
      errors+=( "wp db optimize failed" )
      failed=1
    fi
  fi

  local details
  details=$(jq -nc \
    --argjson transients "$transients" \
    --argjson orphaned "$orphaned" \
    --argjson drafts "$drafts" \
    --argjson locks "$locks" \
    --argjson db_optimised "$db_optimised" \
    '{
      transients_expired: $transients,
      orphaned_postmeta:  $orphaned,
      auto_drafts:        $drafts,
      edit_locks:         $locks,
      db_optimised:       $db_optimised
    }')

  local errors_json
  if (( ${#errors[@]} == 0 )); then
    errors_json='[]'
  else
    errors_json=$(printf '%s\n' "${errors[@]}" | jq -R . | jq -sc .)
  fi

  printf '%s\n' "$details"
  printf '%s\n' "$errors_json"
  return $failed
}

# Internal: shared runner for both fleet functions.
# Args:
#   $1 operation label        e.g. "wp_fleet_update"
#   $2 per-site op function   e.g. "_wp_fleet_update_one"
#   $3 dry_run                "true" or "false"
#   $4 yes                    "true" or "false"
#   $5 json_mode              "true" or "false"
#   $6 only_pattern           glob or empty
#   $7 exclude_pattern        glob or empty
_wp_fleet_run() {
  # Guard against TYPESET_SILENT being unset in the caller's shell (causes
  # `local foo` without a value to auto-print `foo=''` to stdout, which
  # pollutes --json output). local_options restores state on function exit.
  setopt local_options typeset_silent
  local op="$1" op_fn="$2" dry_run="$3" yes="$4" json="$5"
  local only="$6" exclude="$7"

  _wp_fleet_require_jq || return 1

  # Collect and filter sites.
  local all_rows filtered=""
  all_rows=$(_wp_fleet_collect_sites) || return 1

  if [[ -z "$all_rows" ]]; then
    if [[ "$json" == "true" ]]; then
      jq -nc \
        --arg op "$op" \
        --arg started "$(_wp_fleet_now_utc)" \
        --arg finished "$(_wp_fleet_now_utc)" \
        --argjson dry_run $([[ "$dry_run" == "true" ]] && echo true || echo false) \
        '{operation: $op, started_at: $started, finished_at: $finished, dry_run: $dry_run, sites: [], summary: {total: 0, succeeded: 0, failed: 0, skipped: 0}}'
    else
      echo "No wordpress-* MCP servers registered in ~/.claude.json."
      echo "Run wp_mcp_add_site or wp_mcp_add_remote_site to register one first."
    fi
    return 0
  fi

  # Apply --only / --exclude filters against the site name column.
  local row name
  while IFS= read -r row; do
    [[ -z "$row" ]] && continue
    name="${row%%$'\t'*}"
    _wp_fleet_name_matches "$name" "$only" || continue
    if [[ -n "$exclude" ]] && _wp_fleet_name_matches "$name" "$exclude"; then
      continue
    fi
    filtered+="$row"$'\n'
  done <<< "$all_rows"

  if [[ -z "$filtered" ]]; then
    if [[ "$json" == "true" ]]; then
      jq -nc \
        --arg op "$op" \
        --arg started "$(_wp_fleet_now_utc)" \
        --arg finished "$(_wp_fleet_now_utc)" \
        --argjson dry_run $([[ "$dry_run" == "true" ]] && echo true || echo false) \
        '{operation: $op, started_at: $started, finished_at: $finished, dry_run: $dry_run, sites: [], summary: {total: 0, succeeded: 0, failed: 0, skipped: 0}}'
    else
      echo "No sites matched the --only/--exclude filters."
    fi
    return 0
  fi

  # Count sites for the preview/banner and for [i/N] output. Count non-empty
  # lines without depending on grep (the command hash can be stale in a fresh
  # zsh and we already require jq anyway).
  local total=0
  local _count_line
  while IFS= read -r _count_line; do
    [[ -n "$_count_line" ]] && total=$((total + 1))
  done <<< "$filtered"

  # Banner + optional confirmation (suppressed under --json).
  if [[ "$json" != "true" ]]; then
    local dr_label=""
    [[ "$dry_run" == "true" ]] && dr_label=" (DRY RUN)"
    echo "${CLR_BOLD}${CLR_BLUE}$op$dr_label${CLR_NC}"
    echo "${CLR_BLUE}$(printf '=%.0s' {1..60})${CLR_NC}"
    echo "Sites in scope ($total):"
    local row n t p u s
    local -a row_parts
    while IFS= read -r row; do
      [[ -z "$row" ]] && continue
      # zsh's `read` with IFS=$'\t' collapses consecutive tabs (tab is a
      # whitespace IFS char). Use parameter expansion to split preserving
      # empty fields.
      row_parts=( "${(@ps:\t:)row}" )
      n="${row_parts[1]}"; t="${row_parts[2]}"; p="${row_parts[3]}"
      u="${row_parts[4]}"; s="${row_parts[5]}"
      [[ -z "$n" ]] && continue
      if [[ "$t" == "http-proxy" ]]; then
        echo "  - $n  [${CLR_YELLOW}http-proxy$([[ "$dry_run" == "true" ]] || echo ", will skip")${CLR_NC}]"
      else
        echo "  - $n  [${CLR_GREEN}$t${CLR_NC}]  $p${u:+  (url: $u)}"
      fi
    done <<< "$filtered"
    echo ""

    if [[ "$yes" != "true" && "$dry_run" != "true" ]]; then
      read "REPLY?Proceed with $op on $total site(s)? (y/N): "
      if [[ "$REPLY" != "y" && "$REPLY" != "Y" ]]; then
        echo "Cancelled."
        return 0
      fi
    fi
  fi

  # Iterate.
  local started_at finished_at
  started_at=$(_wp_fleet_now_utc)

  local tmp
  tmp=$(mktemp -t wp_fleet_XXXX) || { echo "Error: mktemp failed" >&2; return 1; }
  # shellcheck disable=SC2064  — want $tmp expanded now.
  trap "rm -f '$tmp'" EXIT INT TERM

  local idx=0 succeeded=0 failed_count=0 skipped=0
  # NB: "status" is a read-only special in zsh (alias for $?), so we use
  # site_status. "path" is also special (tied to $PATH) and shows up as $p
  # from the tab-split below — we use $p not $path on purpose.
  local row n t p u s details errors_json site_json site_status rc
  local -a row_parts
  while IFS= read -r row; do
    [[ -z "$row" ]] && continue
    row_parts=( "${(@ps:\t:)row}" )
    n="${row_parts[1]}"; t="${row_parts[2]}"; p="${row_parts[3]}"
    u="${row_parts[4]}"; s="${row_parts[5]}"
    [[ -z "$n" ]] && continue
    idx=$((idx + 1))

    if [[ "$t" == "http-proxy" ]]; then
      [[ "$json" != "true" ]] && echo "[$idx/$total] $n — skipping (remote site, fleet ops require local wp-cli access; see v2 plan in wp-fleet.sh header)"
      site_status="skipped"
      errors_json='["remote site — not implemented in v1"]'
      details='{}'
      site_json=$(_wp_fleet_site_json "$n" "$t" "$p" "$u" "$site_status" "$details" "$errors_json")
      printf '%s\n' "$site_json" >> "$tmp"
      skipped=$((skipped + 1))
      continue
    fi

    if [[ "$t" != "stdio-local" ]]; then
      [[ "$json" != "true" ]] && echo "[$idx/$total] $n — skipping (unknown transport: $t)"
      site_status="skipped"
      errors_json="[\"unknown transport: $t\"]"
      details='{}'
      site_json=$(_wp_fleet_site_json "$n" "$t" "$p" "$u" "$site_status" "$details" "$errors_json")
      printf '%s\n' "$site_json" >> "$tmp"
      skipped=$((skipped + 1))
      continue
    fi

    if [[ ! -d "$p" ]]; then
      [[ "$json" != "true" ]] && echo "[$idx/$total] $n — skipping (path not found: $p)"
      site_status="skipped"
      errors_json="[\"path not found: $p\"]"
      details='{}'
      site_json=$(_wp_fleet_site_json "$n" "$t" "$p" "$u" "$site_status" "$details" "$errors_json")
      printf '%s\n' "$site_json" >> "$tmp"
      skipped=$((skipped + 1))
      continue
    fi

    [[ "$json" != "true" ]] && echo "[$idx/$total] $n"

    # Run the per-site op. Capture stdout (two NDJSON lines), let stderr flow
    # in human mode; suppress stderr entirely in --json mode.
    local op_out
    if [[ "$json" == "true" ]]; then
      op_out=$("$op_fn" "$dry_run" "$p" "$u" 2>/dev/null)
      rc=$?
    else
      op_out=$("$op_fn" "$dry_run" "$p" "$u" 2> >(sed 's/^/    /' >&2))
      rc=$?
    fi

    # Split the two NDJSON lines back into details + errors.
    details="${op_out%%$'\n'*}"
    errors_json="${op_out#*$'\n'}"
    [[ -z "$details" ]] && details='{}'
    [[ -z "$errors_json" || "$errors_json" == "$op_out" ]] && errors_json='[]'

    if [[ "$dry_run" == "true" ]]; then
      site_status="dry-run"
      succeeded=$((succeeded + 1))
    elif [[ $rc -eq 0 ]]; then
      site_status="success"
      succeeded=$((succeeded + 1))
    else
      site_status="failed"
      failed_count=$((failed_count + 1))
    fi

    site_json=$(_wp_fleet_site_json "$n" "$t" "$p" "$u" "$site_status" "$details" "$errors_json")
    printf '%s\n' "$site_json" >> "$tmp"
  done <<< "$filtered"

  finished_at=$(_wp_fleet_now_utc)

  # Emit the final document.
  local dry_run_json=false
  [[ "$dry_run" == "true" ]] && dry_run_json=true

  local summary
  summary=$(jq -nc \
    --argjson total "$total" \
    --argjson succeeded "$succeeded" \
    --argjson failed "$failed_count" \
    --argjson skipped "$skipped" \
    '{total: $total, succeeded: $succeeded, failed: $failed, skipped: $skipped}')

  if [[ "$json" == "true" ]]; then
    jq -s \
      --arg op "$op" \
      --arg started "$started_at" \
      --arg finished "$finished_at" \
      --argjson dry_run "$dry_run_json" \
      --argjson summary "$summary" \
      '{operation: $op, started_at: $started, finished_at: $finished, dry_run: $dry_run, sites: ., summary: $summary}' \
      "$tmp"
  else
    echo ""
    echo "${CLR_BOLD}${CLR_BLUE}Summary${CLR_NC}"
    echo "  total:     $total"
    echo "  ${CLR_GREEN}succeeded: $succeeded${CLR_NC}"
    [[ $failed_count -gt 0 ]] && echo "  ${CLR_RED}failed:    $failed_count${CLR_NC}" || echo "  failed:    0"
    [[ $skipped -gt 0 ]] && echo "  ${CLR_YELLOW}skipped:   $skipped${CLR_NC}" || echo "  skipped:   0"
    if [[ $failed_count -gt 0 ]]; then
      echo ""
      echo "${CLR_RED}Failures:${CLR_NC}"
      jq -r '.[] | select(.status == "failed") | "  - \(.name): \((.errors // []) | join("; "))"' "$tmp" 2>/dev/null \
        || cat "$tmp"
    fi
  fi

  rm -f "$tmp"
  trap - EXIT INT TERM
  [[ $failed_count -gt 0 ]] && return 1
  return 0
}

# Internal: parse shared fleet flags from "$@". Sets shell variables in the
# caller's scope (relies on zsh function scoping, which is dynamic for
# explicitly declared locals). Uses a sentinel FLEET_FLAGS_OK=1 on success.
# Prints usage on --help and sets FLEET_FLAGS_HELP=1.
_wp_fleet_parse_flags() {
  dry_run=false
  yes=false
  json=false
  only=""
  exclude=""
  FLEET_FLAGS_OK=0
  FLEET_FLAGS_HELP=0

  while (( $# > 0 )); do
    case "$1" in
      --dry-run|-n)   dry_run=true ;;
      --yes|-y)       yes=true ;;
      --json)         json=true ;;
      --only=*)       only="${1#--only=}" ;;
      --exclude=*)    exclude="${1#--exclude=}" ;;
      --help|-h)      FLEET_FLAGS_HELP=1; return 0 ;;
      *)
        echo "Error: unknown option: $1" >&2
        return 1
        ;;
    esac
    shift
  done

  # --json implies --yes (no prompts when producing machine output).
  [[ "$json" == "true" ]] && yes=true

  FLEET_FLAGS_OK=1
  return 0
}

# Run plugin, theme and core updates across every registered WordPress site.
#
# Purpose: Bulk fleet update. Iterates the wordpress-* MCP entries in
#          ~/.claude.json and runs the equivalent of `updatem` against each
#          local site (plugins -> themes -> core). Failures on individual
#          sites are aggregated; the run always completes.
#
# Usage: wp_fleet_update [options]
#   --dry-run, -n        Preview pending updates without applying
#   --yes, -y            Skip the interactive confirmation
#   --json               Emit machine-readable JSON (suppresses decoration)
#   --only=<pattern>     Glob filter over server names (e.g. --only=colacnew)
#   --exclude=<pattern>  Inverse glob filter
#   --help, -h           Show this help
#
# Examples:
#   wp_fleet_update --dry-run
#   wp_fleet_update --only=colacnew --dry-run
#   wp_fleet_update --yes
#   wp_fleet_update --json --yes | jq '.summary'
#
# What it does:
# 1. Reads every wordpress-* MCP server from ~/.claude.json
# 2. Applies --only / --exclude filters
# 3. For each local (stdio-local) site: counts pending updates, then runs
#    `wp plugin update --all`, `wp theme update --all`, `wp core update`
#    using --path= (and --url= if the MCP entry has one)
# 4. Skips remote (http-proxy) sites — see design decision 1 in the header
# 5. Aggregates per-site results and emits a summary (text or JSON)
#
# Requirements:
# - jq on PATH (brew install jq)
# - wp-cli on PATH
# - ~/.claude.json present with at least one wordpress-* entry
#
# After running:
# - Text mode: summary of total/succeeded/failed/skipped with failure details
# - JSON mode: single JSON document on stdout; all other output suppressed
wp_fleet_update() {
  setopt local_options typeset_silent
  local dry_run yes json only exclude FLEET_FLAGS_OK FLEET_FLAGS_HELP
  _wp_fleet_parse_flags "$@" || return 1
  if (( FLEET_FLAGS_HELP == 1 )); then
    # Re-echo the help block by reading this function's usage docblock above.
    cat <<'EOF'
wp_fleet_update — run plugin/theme/core updates across every registered WP site.

USAGE:
  wp_fleet_update [options]

OPTIONS:
  --dry-run, -n        Preview pending updates without applying
  --yes, -y            Skip the interactive confirmation
  --json               Emit machine-readable JSON (suppresses decoration)
  --only=<pattern>     Glob filter over server names (e.g. --only=colacnew)
  --exclude=<pattern>  Inverse glob filter
  --help, -h           Show this help

EXAMPLES:
  wp_fleet_update --dry-run
  wp_fleet_update --only=colacnew --dry-run
  wp_fleet_update --yes
  wp_fleet_update --json --yes | jq '.summary'

See the wp-fleet.sh header for JSON shape and design decisions.
EOF
    return 0
  fi

  _wp_fleet_run "wp_fleet_update" "_wp_fleet_update_one" \
    "$dry_run" "$yes" "$json" "$only" "$exclude"
}

# Run a safe DB cleanup across every registered WordPress site.
#
# Purpose: Bulk fleet DB maintenance. Deletes expired transients, orphaned
#          postmeta, stale auto-drafts, stale edit locks, and runs
#          `wp db optimize`. Deliberately a SAFE SUBSET of wp_db_optimise —
#          no plugin state changes, no wp-config rewrites, no activations
#          or deactivations. See design decision 2 in the wp-fleet.sh header.
#
# Usage: wp_fleet_db_optimise [options]
#   --dry-run, -n        Count eligible rows without deleting anything
#   --yes, -y            Skip the interactive confirmation
#   --json               Emit machine-readable JSON (suppresses decoration)
#   --only=<pattern>     Glob filter over server names
#   --exclude=<pattern>  Inverse glob filter
#   --help, -h           Show this help
#
# Examples:
#   wp_fleet_db_optimise --dry-run
#   wp_fleet_db_optimise --only=colacnew --dry-run
#   wp_fleet_db_optimise --yes
#   wp_fleet_db_optimise --json --yes | jq '.sites[] | {name, details}'
#
# What it does (per site):
# 1. Resolves the table prefix via `wp db prefix`
# 2. Counts eligible rows for each cleanup (used for dry-run preview and the summary)
# 3. Runs `wp transient delete --expired`
# 4. Deletes orphaned postmeta (rows whose post_id no longer exists)
# 5. Deletes auto-draft posts older than 7 days
# 6. Deletes edit-lock postmeta older than 7 days
# 7. Runs `wp db optimize`
#
# Requirements:
# - jq on PATH
# - wp-cli on PATH
#
# What it deliberately does NOT do (vs wp_db_optimise):
# - No plugin deactivation/activation
# - No wp-config constant rewrites (WP_MEMORY_LIMIT, DISABLE_WP_CRON, etc)
# - No plugin-specific table truncation (SEOPress, Jetpack, GravitySMTP, etc)
# Fleet runs may include production sites; this keeps the operation safe.
wp_fleet_db_optimise() {
  setopt local_options typeset_silent
  local dry_run yes json only exclude FLEET_FLAGS_OK FLEET_FLAGS_HELP
  _wp_fleet_parse_flags "$@" || return 1
  if (( FLEET_FLAGS_HELP == 1 )); then
    cat <<'EOF'
wp_fleet_db_optimise — run a safe DB cleanup across every registered WP site.

USAGE:
  wp_fleet_db_optimise [options]

OPTIONS:
  --dry-run, -n        Count eligible rows without deleting
  --yes, -y            Skip the interactive confirmation
  --json               Emit machine-readable JSON (suppresses decoration)
  --only=<pattern>     Glob filter over server names
  --exclude=<pattern>  Inverse glob filter
  --help, -h           Show this help

OPERATIONS (per site):
  1. Count eligible rows for each cleanup
  2. wp transient delete --expired
  3. DELETE orphaned postmeta
  4. DELETE stale auto-drafts (>7 days)
  5. DELETE stale edit locks (>7 days)
  6. wp db optimize

NOT PERFORMED (vs wp_db_optimise):
  - No plugin activate/deactivate
  - No wp-config rewrites
  - No plugin-specific table truncation
  Fleet runs may include production sites; this keeps the operation safe.

EXAMPLES:
  wp_fleet_db_optimise --dry-run
  wp_fleet_db_optimise --only=colacnew --dry-run
  wp_fleet_db_optimise --yes
  wp_fleet_db_optimise --json --yes | jq '.sites[] | {name, details}'

See the wp-fleet.sh header for JSON shape and design decisions.
EOF
    return 0
  fi

  _wp_fleet_run "wp_fleet_db_optimise" "_wp_fleet_db_optimise_one" \
    "$dry_run" "$yes" "$json" "$only" "$exclude"
}
