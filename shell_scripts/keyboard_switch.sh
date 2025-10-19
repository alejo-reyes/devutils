#!/bin/bash

function keyboard_switch() {
  local action="$1"
  
  # Find Magic Keyboard info
  id=$(blueutil --paired | grep "Magic Keyboard" | grep -Eo '[a-z0-9]{2}(-[a-z0-9]{2}){5}')
  name=$(blueutil --paired | grep "Magic Keyboard" | grep -Eo 'name: "\S+"')
  
  if [[ -z "$id" ]]; then
    echo "Magic Keyboard not found in paired devices"
    echo "Available paired devices:"
    blueutil --paired
    return 1
  fi
  
  case "$action" in
    "claim"|"c")
      echo "Claiming Magic Keyboard..."
      echo "📱 Device: $id, $name"
      
      # Check if already connected
      if blueutil --is-connected "$id" &>/dev/null; then
        echo "Keyboard already connected to this laptop"
        return 0
      fi
      
      echo "🔌 Unpairing from any previous connection..."
      blueutil --unpair "$id"
      
      echo "⏳ Waiting for keyboard to enter pairable mode..."
      sleep 3
      
      echo "🔗 Pairing with this laptop..."
      blueutil --pair "$id" "0000"
      
      echo "📡 Connecting..."
      blueutil --connect "$id"
      
      if blueutil --is-connected "$id" &>/dev/null; then
        echo "Magic Keyboard successfully claimed and connected!"
      else
        echo "Failed to connect. Try running the command again."
        return 1
      fi
      ;;
      
    "release"|"r")
      echo "🔓 Releasing Magic Keyboard..."
      echo "📱 Device: $id, $name"
      
      # Check if connected
      if ! blueutil --is-connected "$id" &>/dev/null; then
        echo "Keyboard not currently connected to this laptop"
      else
        echo "🔌 Disconnecting..."
        blueutil --disconnect "$id"
        echo "Magic Keyboard disconnected and ready for other device"
      fi
      ;;
      
    "status"|"s")
      echo "Magic Keyboard Status:"
      echo "Device: $id, $name"
      
      if blueutil --is-connected "$id" &>/dev/null; then
        echo "Connected to this laptop"
      else
        echo "Not connected to this laptop"
      fi
      ;;
      
    *)
      echo "Magic Keyboard Switcher"
      echo ""
      echo "Usage: keyboard_switch <action>"
      echo ""
      echo "Actions:"
      echo "  claim|c     - Claim keyboard for this laptop (unpair & reconnect)"
      echo "  release|r   - Release keyboard (disconnect so other laptop can use)"
      echo "  status|s    - Check current connection status"
      echo ""
      echo "Examples:"
      echo "  keyboard_switch claim"
      echo "  keyboard_switch c"
      echo "  keyboard_switch release"
      echo "  keyboard_switch r"
      echo "  keyboard_switch status"
      return 1
      ;;
  esac
}

# Allow calling the function directly if script is executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  keyboard_switch "$1"
fi