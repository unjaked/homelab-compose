#!/usr/bin/env bash
set -euo pipefail

DRY_RUN="${DRY_RUN:-1}"
FORCE="${FORCE:-0}"

ROOTS=(
  "/data/media/movies"
  "/data/media/tv"
)

DEBRID_MOUNT="/mnt/decypharr"
LOG_DIR="/home/jacob/homelab-compose/media/logs"
TS="$(date +%Y%m%d-%H%M%S)"
LOG_FILE="$LOG_DIR/cleanup-broken-symlinks-$TS.log"
ALL_LINKS="$LOG_DIR/all-symlinks-$TS.txt"
BROKEN_LINKS="$LOG_DIR/broken-symlinks-$TS.txt"

mkdir -p "$LOG_DIR"

exec 9>/tmp/cleanup-broken-media-symlinks.lock
if ! flock -n 9; then
  echo "Another cleanup is already running."
  exit 1
fi

{
  echo "=== cleanup started: $(date) ==="
  echo "DRY_RUN=$DRY_RUN"
  echo "FORCE=$FORCE"
  echo

  echo "=== Decypharr mount sanity check ==="

  if [[ ! -d "$DEBRID_MOUNT/__all__" ]]; then
    echo "ABORT: $DEBRID_MOUNT/__all__ does not exist."
    exit 1
  fi

  if [[ ! -f "$DEBRID_MOUNT/version.txt" ]]; then
    echo "ABORT: $DEBRID_MOUNT/version.txt does not exist."
    exit 1
  fi

  if ! find "$DEBRID_MOUNT/__all__" -mindepth 1 -maxdepth 1 -print -quit | grep -q .; then
    echo "ABORT: $DEBRID_MOUNT/__all__ appears empty."
    exit 1
  fi

  : > "$ALL_LINKS"
  : > "$BROKEN_LINKS"

  echo
  echo "=== scanning media roots ==="

  for root in "${ROOTS[@]}"; do
    if [[ -d "$root" ]]; then
      echo "Scanning $root"
      find "$root" -type l -print >> "$ALL_LINKS"
      find "$root" -xtype l -print >> "$BROKEN_LINKS"
    else
      echo "Skipping missing root: $root"
    fi
  done

  TOTAL="$(wc -l < "$ALL_LINKS" | tr -d ' ')"
  BROKEN="$(wc -l < "$BROKEN_LINKS" | tr -d ' ')"

  echo
  echo "Total symlinks:  $TOTAL"
  echo "Broken symlinks: $BROKEN"
  echo "Broken list:     $BROKEN_LINKS"

  if [[ "$TOTAL" -gt 50 ]]; then
    PCT=$(( BROKEN * 100 / TOTAL ))
  else
    PCT=0
  fi

  echo "Broken percent:  $PCT%"

  if [[ "$TOTAL" -gt 50 && "$PCT" -gt 50 && "$FORCE" != "1" ]]; then
    echo
    echo "ABORT: more than 50% of symlinks appear broken."
    echo "This may mean Decypharr is down or temporarily unmounted."
    echo "Use FORCE=1 only after confirming the mount is healthy."
    exit 1
  fi

  if [[ "$BROKEN" -eq 0 ]]; then
    echo
    echo "No broken symlinks found."
    exit 0
  fi

  echo
  echo "=== first 100 broken symlinks ==="
  sed -n '1,100p' "$BROKEN_LINKS"

  if [[ "$DRY_RUN" == "1" ]]; then
    echo
    echo "DRY RUN ONLY: nothing deleted."
    echo "Run with DRY_RUN=0 to delete broken symlinks."
    exit 0
  fi

  echo
  echo "=== deleting broken symlinks ==="
  while IFS= read -r path; do
    rm -v -- "$path"
  done < "$BROKEN_LINKS"

  echo
  echo "=== deleting empty media directories ==="
  for root in "${ROOTS[@]}"; do
    if [[ -d "$root" ]]; then
      find "$root" -mindepth 1 -depth -type d -empty -print -delete
    fi
  done

  echo
  echo "=== cleanup finished: $(date) ==="
} | tee -a "$LOG_FILE"
