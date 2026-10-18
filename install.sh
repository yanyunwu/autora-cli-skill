#!/bin/sh
set -eu

autora_fail() {
  printf 'Autora install: %s\n' "$*" >&2
  exit 1
}

autora_usage() {
  cat <<'USAGE'
Usage: sh install.sh [--bin-dir DIRECTORY] [--no-path]

Install the matching executable bundled in this skill's scripts directory.
Repository binaries: Linux amd64/arm64 and macOS arm64.
Defaults: ~/.local/bin on Linux/macOS, %LOCALAPPDATA%/Autora/bin on Windows.
The installer updates the current user's command search path.
Use --no-path to copy the executable without changing PATH configuration.
Windows requires Git Bash, MSYS2 or Cygwin; WSL uses the Linux package.
USAGE
}

autora_install_dir=
autora_update_path=1
while [ "$#" -gt 0 ]; do
  case "$1" in
    --bin-dir)
      [ "$#" -ge 2 ] && [ -n "$2" ] || autora_fail "--bin-dir requires a directory"
      autora_install_dir=$2
      shift 2
      ;;
    --no-path)
      autora_update_path=0
      shift
      ;;
    --help|-h)
      autora_usage
      exit 0
      ;;
    *)
      autora_fail "unknown option: $1"
      ;;
  esac
done

autora_skill_dir=$(CDPATH= cd -P "$(dirname "$0")" && pwd -P)
autora_platform=$(uname -s)
autora_arch=$(uname -m)
case "$autora_arch" in
  x86_64|amd64) autora_arch=amd64 ;;
  aarch64|arm64) autora_arch=arm64 ;;
  *) autora_fail "unsupported architecture: $autora_arch" ;;
esac
case "$autora_platform" in
  MINGW*|MSYS*|CYGWIN*)
    autora_artifact_platform=windows-$autora_arch
    autora_windows=1
    autora_binary_name=autora.exe
    if [ -z "$autora_install_dir" ]; then
      [ -n "${LOCALAPPDATA:-}" ] || autora_fail "LOCALAPPDATA is missing; use --bin-dir"
      autora_install_dir=$(cygpath -u "$LOCALAPPDATA")/Autora/bin
    fi
    ;;
  Linux|Darwin)
    case "$autora_platform" in
      Linux) autora_artifact_platform=linux-$autora_arch ;;
      Darwin) autora_artifact_platform=darwin-$autora_arch ;;
    esac
    autora_windows=0
    autora_binary_name=autora
    if [ -z "$autora_install_dir" ]; then
      [ -n "${HOME:-}" ] || autora_fail "HOME is missing; use --bin-dir"
      autora_install_dir=$HOME/.local/bin
    fi
    ;;
  *)
    autora_fail "unsupported platform: $autora_platform"
    ;;
esac

autora_source=$autora_skill_dir/scripts/$autora_artifact_platform/$autora_binary_name
if [ ! -f "$autora_source" ]; then
  # Generated single-platform bundles retain their compact scripts/autora layout.
  autora_source=$autora_skill_dir/scripts/$autora_binary_name
fi
[ -f "$autora_source" ] || autora_fail "missing scripts/$autora_artifact_platform/$autora_binary_name or bundled scripts/$autora_binary_name; use a package built for this system"

mkdir -p "$autora_install_dir"
autora_install_dir=$(CDPATH= cd -P "$autora_install_dir" && pwd -P)
autora_stage=$(mktemp -d "$autora_install_dir/.autora-install.XXXXXX")
case "$autora_stage/" in
  "$autora_install_dir/"*) ;;
  *) autora_fail "temporary directory is outside the installation directory" ;;
esac
autora_cleanup() {
  rm -f "$autora_stage/$autora_binary_name"
  rmdir "$autora_stage" 2>/dev/null || :
}
trap autora_cleanup 0
trap 'exit 130' 2
trap 'exit 143' 15
trap 'exit 129' 1

cp "$autora_source" "$autora_stage/$autora_binary_name"
chmod 755 "$autora_stage/$autora_binary_name"
autora_version=$("$autora_stage/$autora_binary_name" --version 2>/dev/null) ||
  autora_fail "bundled executable cannot run on this system; the existing command was kept"
mv -f "$autora_stage/$autora_binary_name" "$autora_install_dir/$autora_binary_name"

autora_add_profile() {
  autora_profile=$1
  mkdir -p "$(dirname "$autora_profile")"
  if [ -f "$autora_profile" ] && grep -Fqx "$autora_path_statement" "$autora_profile"; then
    return
  fi
  printf '\n# Autora CLI\n%s\n' "$autora_path_statement" >> "$autora_profile"
}

if [ "$autora_update_path" -eq 1 ]; then
  if [ "$autora_windows" -eq 1 ]; then
    case "$autora_install_dir" in
      *';'*) autora_fail "the directory contains a PATH separator; use --no-path" ;;
    esac
    autora_windows_dir=$(cygpath -w "$autora_install_dir")
    if command -v powershell.exe >/dev/null 2>&1; then
      autora_powershell=powershell.exe
    elif command -v pwsh.exe >/dev/null 2>&1; then
      autora_powershell=pwsh.exe
    else
      autora_fail "PowerShell is required to update user PATH; use --no-path"
    fi
    AUTORA_INSTALL_BIN_WINDOWS="$autora_windows_dir" "$autora_powershell" -NoLogo -NoProfile -NonInteractive -Command '
$ErrorActionPreference = "Stop"
$autoraBin = $env:AUTORA_INSTALL_BIN_WINDOWS
$autoraUserPath = [Environment]::GetEnvironmentVariable("Path", "User")
$autoraEntries = @($autoraUserPath -split ";" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
$autoraPresent = $false
foreach ($autoraEntry in $autoraEntries) {
  $autoraExpanded = [Environment]::ExpandEnvironmentVariables($autoraEntry).TrimEnd([char]92, [char]47)
  if ([string]::Equals($autoraExpanded, $autoraBin.TrimEnd([char]92, [char]47), [StringComparison]::OrdinalIgnoreCase)) {
    $autoraPresent = $true
    break
  }
}
if (-not $autoraPresent) {
  $autoraNewPath = (@($autoraBin) + $autoraEntries) -join ";"
  [Environment]::SetEnvironmentVariable("Path", $autoraNewPath, "User")
}
'
  fi
  [ -n "${HOME:-}" ] || autora_fail "HOME is required to update shell PATH; use --no-path"
  case "$autora_install_dir" in
    *:*) autora_fail "the directory contains a PATH separator; use --no-path" ;;
  esac
  autora_quoted_path=$(printf '%s' "$autora_install_dir" | sed "s/'/'\\\\''/g")
  autora_path_statement=$(printf 'case ":$PATH:" in *:\047%s\047:*) ;; *) export PATH=\047%s\047:"$PATH" ;; esac' "$autora_quoted_path" "$autora_quoted_path")
  autora_user_shell=${SHELL:-sh}
  case "${autora_user_shell##*/}" in
    fish)
      autora_path_statement=$(printf 'if not contains -- \047%s\047 $PATH; set -gx PATH \047%s\047 $PATH; end' "$autora_quoted_path" "$autora_quoted_path")
      autora_add_profile "${XDG_CONFIG_HOME:-$HOME/.config}/fish/conf.d/autora-cli-path.fish"
      ;;
    zsh)
      autora_add_profile "${ZDOTDIR:-$HOME}/.zshrc"
      ;;
    bash)
      autora_add_profile "$HOME/.bashrc"
      if [ -f "$HOME/.bash_profile" ]; then
        autora_add_profile "$HOME/.bash_profile"
      elif [ -f "$HOME/.bash_login" ]; then
        autora_add_profile "$HOME/.bash_login"
      else
        autora_add_profile "$HOME/.profile"
      fi
      ;;
    *)
      autora_add_profile "$HOME/.profile"
      ;;
  esac
fi

printf 'Installed %s at %s/%s\n' "$autora_version" "$autora_install_dir" "$autora_binary_name"
if [ "$autora_update_path" -eq 1 ]; then
  printf 'Open a new terminal and run: autora --help\n'
fi
