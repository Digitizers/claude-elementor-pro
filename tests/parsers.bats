#!/usr/bin/env bats
# Unit tests for new-client.sh pure parsers, invoked via its --self-test-fn hook.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SCRIPT="$REPO_ROOT/new-client.sh"
  FIX="$BATS_TEST_DIRNAME/fixtures"
}

# ---- parse_user_id ----
@test "parse_user_id extracts id from users/me" {
  run bash -c "'$SCRIPT' --self-test-fn parse_user_id < '$FIX/users-me.json'"
  [ "$status" -eq 0 ]
  [ "$output" = "7" ]
}

@test "parse_user_id returns empty on bad-auth payload {}" {
  run bash -c "printf '{}' | '$SCRIPT' --self-test-fn parse_user_id"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "parse_user_id degrades to empty on garbage (no crash)" {
  run bash -c "printf 'not json' | '$SCRIPT' --self-test-fn parse_user_id"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# ---- plugin_active ----
@test "plugin_active yes for active elementor" {
  run bash -c "'$SCRIPT' --self-test-fn plugin_active elementor < '$FIX/plugins.json'"
  [ "$output" = "yes" ]
}

@test "plugin_active no for inactive elementor-pro" {
  run bash -c "'$SCRIPT' --self-test-fn plugin_active elementor-pro < '$FIX/plugins.json'"
  [ "$output" = "no" ]
}

@test "plugin_active does not prefix-false-match (element vs elementor)" {
  run bash -c "'$SCRIPT' --self-test-fn plugin_active element < '$FIX/plugins.json'"
  [ "$output" = "no" ]
}

@test "plugin_active degrades to no on malformed json (no crash)" {
  run bash -c "'$SCRIPT' --self-test-fn plugin_active elementor < '$FIX/plugins-malformed.json'"
  [ "$status" -eq 0 ]
  [ "$output" = "no" ]
}

# ---- release_zip_url ----
@test "release_zip_url picks the .zip asset over the .txt" {
  run bash -c "'$SCRIPT' --self-test-fn release_zip_url < '$FIX/release.json'"
  [ "$output" = "https://example.com/widget.zip" ]
}

@test "release_zip_url falls back to zipball_url when no asset" {
  run bash -c "'$SCRIPT' --self-test-fn release_zip_url < '$FIX/release-no-asset.json'"
  [ "$output" = "https://api.github.com/repos/acme/widget/zipball/v1" ]
}

# ---- b64_auth ----
@test "b64_auth produces correct base64 with no trailing newline" {
  run "$SCRIPT" --self-test-fn b64_auth Digitizer secret
  [ "$output" = "RGlnaXRpemVyOnNlY3JldA==" ]
}

# ---- Tier-0 dynamic-data detection (JetEngine / ACF) ----
@test "plugin_active detects active jet-engine" {
  run bash -c "'$SCRIPT' --self-test-fn plugin_active jet-engine < '$FIX/plugins-jet-acf.json'"
  [ "$output" = "yes" ]
}

@test "plugin_active detects active advanced-custom-fields-pro" {
  run bash -c "'$SCRIPT' --self-test-fn plugin_active advanced-custom-fields-pro < '$FIX/plugins-jet-acf.json'"
  [ "$output" = "yes" ]
}

@test "plugin_active reports jet-engine absent on a plain elementor site" {
  run bash -c "'$SCRIPT' --self-test-fn plugin_active jet-engine < '$FIX/plugins.json'"
  [ "$output" = "no" ]
}

@test "plugin_active ACF-free slug does not match the -pro plugin (exact-segment)" {
  # advanced-custom-fields-pro must NOT be matched by the free slug — the HAS_ACF
  # loop checks both slugs explicitly precisely because of this.
  run bash -c "'$SCRIPT' --self-test-fn plugin_active advanced-custom-fields < '$FIX/plugins-jet-acf.json'"
  [ "$output" = "no" ]
}

# ---- regression: readonly builtin name (the WP_UID bug) ----
@test "script never assigns to readonly shell builtin names" {
  # UID/EUID/PPID/BASHPID are readonly; assigning silently no-ops under set +e,
  # which is how the original auth-bypass shipped. Guard at the source level.
  run grep -nE '^\s*(UID|EUID|PPID|BASHPID)=' "$SCRIPT"
  [ "$status" -ne 0 ]   # grep found nothing -> good
}
