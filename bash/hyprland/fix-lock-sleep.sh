#!/bin/bash
# Simple function to fix the oopsie lock screen problem on resume from sleep
function fix-lock-sleep() {
  hyprctl --instance 0 'keyword misc:allow_session_lock_restore 1'
  hyprctl --instance 0 'dispatch exec hyprlock'
  echo "Switch back to the GUI instances with zntrl+alt+F1 now"
}
