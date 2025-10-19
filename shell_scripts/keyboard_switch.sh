#!/bin/bash

function keyboard_switch() {
  local action="$1"
  
  # Color codes
  local RED='\033[0;31m'
  local GREEN='\033[0;32m'
  local YELLOW='\033[1;33m'
  local BLUE='\033[0;34m'
  local CYAN='\033[0;36m'
  local GRAY='\033[0;37m'
  local BOLD='\033[1m'
  local NC='\033[0m' # No Color
  
  # Find Magic Keyboard info - first try paired devices
  id=$(blueutil --paired | grep "A.Reyes MagicKeyboard" | grep -Eo '[a-z0-9]{2}(-[a-z0-9]{2}){5}')
  name=$(blueutil --paired | grep "A.Reyes MagicKeyboard" | grep -Eo 'name: "\S+"')
  
  # If not found in paired devices, search nearby devices via inquiry
  if [[ -z "$id" ]]; then
    echo -e "\n${YELLOW}Magic Keyboard not found in paired devices, searching nearby...${NC}"
    id=$(blueutil --inquiry | grep "A.Reyes MagicKeyboard" | grep -Eo '[a-z0-9]{2}(-[a-z0-9]{2}){5}')
    name=$(blueutil --inquiry | grep "A.Reyes MagicKeyboard" | grep -Eo 'name: "\S+"')
    
    if [[ -z "$id" ]]; then
      echo -e "\n${RED}Magic Keyboard not found in paired or nearby devices${NC}"
      echo -e "\t${GRAY}Make sure your Magic Keyboard is:${NC}"
      echo -e "\t\t${GRAY}1. Turned on and in pairing mode${NC}"
      echo -e "\t\t${GRAY}2. Within Bluetooth range${NC}"
      echo -e ""
      echo -e "\n${BLUE}Available paired devices:${NC}"
      blueutil --paired | while read -r line; do
        device_id=$(echo "$line" | grep -Eo '[a-z0-9]{2}(-[a-z0-9]{2}){5}')
        device_name=$(echo "$line" | grep -Eo 'name: "\S+"' | sed 's/name: "//' | sed 's/"//')
        if [[ -n "$device_id" && -n "$device_name" ]]; then
          echo -e "\t${CYAN}$device_id${NC} - ${GRAY}$device_name${NC}"
        fi
      done
      return 1
    else
      echo -e "\n${GREEN}Found Magic Keyboard nearby: $id${NC}"
    fi
  fi
  
  case "$action" in
    "claim"|"c")
      echo -e "\n${BOLD}${BLUE}Claiming Magic Keyboard...${NC}"
      echo -e "\t${GRAY}Device: $id, $name${NC}"
      
      # Check if already connected
      if [[ "$(blueutil --is-connected "$id")" == "1" ]]; then
        echo -e "\n${GREEN}Keyboard already connected to this laptop${NC}"
        return 0
      fi
      
      # Check if device is already paired
      if blueutil --paired | grep -q "$id"; then
        echo -e "\n${YELLOW}Keyboard already paired, connecting...${NC}"
      else
        echo -e "\n${YELLOW}Keyboard not paired, pairing now...${NC}"
        echo -e "\t${GRAY}Waiting for keyboard to enter pairable mode...${NC}"
        sleep 2
        
        echo -e "\n${BLUE}Pairing with this laptop...${NC}"
        blueutil --pair "$id" "0000"
        sleep 2

        if ! blueutil --paired | grep -q "$id"; then
          echo -e "\n${RED}Failed to pair. Make sure keyboard is in pairing mode and try again.${NC}"
          return 1
        fi
      fi
      
      echo -e "\n${BLUE}Connecting...${NC}"
      blueutil --connect "$id"
      
      if [[ "$(blueutil --is-connected "$id")" == "1" ]]; then
        echo -e "\n${BOLD}${GREEN}Magic Keyboard successfully claimed and connected!${NC}"
      else
        echo -e "\n${RED}Failed to connect. Try running the command again.${NC}"
        return 1
      fi
      ;;
      
    "release"|"r")
      echo -e "\n${BOLD}${YELLOW}Releasing Magic Keyboard...${NC}"
      echo -e "\t${GRAY}Device: $id, $name${NC}"
      
      # Check if connected
      if [[ "$(blueutil --is-connected "$id")" == "0" ]]; then
        echo -e "\n${YELLOW}Keyboard not currently connected to this laptop${NC}"
      else
        echo -e "\n${BLUE}Disconnecting...${NC}"
        blueutil --unpair "$id"
        echo -e "\n${GREEN}Magic Keyboard disconnected and ready for other device${NC}"
      fi
      ;;
      
    "status"|"s")
      echo -e "\n${BOLD}${CYAN}Magic Keyboard Status:${NC}"
      echo -e "\t${GRAY}Device: $id, $name${NC}"
      
      if [[ "$(blueutil --is-connected "$id")" == "1" ]]; then
        echo -e "\n${GREEN}Connected to this laptop${NC}"
      else
        echo -e "\n${YELLOW}Not connected to this laptop${NC}"
      fi
      ;;
      
    *)
      echo -e "${BOLD}${CYAN}Magic Keyboard Switcher${NC}"
      echo -e ""
      echo -e "${BOLD}Usage:${NC} keyboard_switch <action>"
      echo -e ""
      echo -e "${BOLD}Actions:${NC}"
      echo -e "  ${GREEN}claim|c${NC}     - Claim keyboard for this laptop (unpair & reconnect)"
      echo -e "  ${YELLOW}release|r${NC}   - Release keyboard (disconnect so other laptop can use)"
      echo -e "  ${BLUE}status|s${NC}    - Check current connection status"
      echo -e ""
      echo -e "${BOLD}Examples:${NC}"
      echo -e "  ${GRAY}keyboard_switch claim${NC}"
      echo -e "  ${GRAY}keyboard_switch c${NC}"
      echo -e "  ${GRAY}keyboard_switch release${NC}"
      echo -e "  ${GRAY}keyboard_switch r${NC}"
      echo -e "  ${GRAY}keyboard_switch status${NC}"
      return 1
      ;;
  esac
}

# Allow calling the function directly if script is executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  keyboard_switch "$1"
fi