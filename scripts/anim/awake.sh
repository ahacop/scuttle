# Sourced by the scripts that record, after `here` is set. Keeps the display awake for as long as the script runs,
# and stops it when the screen is locked: with the display asleep no display link fires, so nothing animates, and
# a locked screen is all the recording would show. A Mac left alone sleeps its display and then locks, so a long
# run started without this measured nothing from then on.
if [[ -z "${ANIM_AWAKE:-}" ]]; then
  exec env ANIM_AWAKE=1 caffeinate -dimsu "$0" "$@"
fi
if ioreg -n Root -d1 -a | grep -A1 CGSSessionScreenIsLocked | grep -q '<true/>'; then
  echo "scripts/anim: the screen is locked, so there is nothing to record; unlock it and run this again" >&2
  exit 75
fi
