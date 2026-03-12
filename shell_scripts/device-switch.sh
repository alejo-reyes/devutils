#!/bin/bash

# Device configuration constants
readonly KEYBOARD_NAME="A.Reyes MagicKeyboard"
readonly MOUSE_NAME="A.Reyes MagicMouse"
readonly KEYBOARD_PIN="0000"
readonly MOUSE_PIN=""  # Mice typically don't need PIN

function device_switch() {
  local device_type="$1"
  local action="$2"
  
  # Color codes
  local RED='\033[0;31m'
  local GREEN='\033[0;32m'
  local YELLOW='\033[1;33m'
  local BLUE='\033[0;34m'
  local CYAN='\033[0;36m'
  local MAGENTA='\033[0;35m'
  local GRAY='\033[0;37m'
  local BOLD='\033[1m'
  local NC='\033[0m' # No Color
  
  # Validate input parameters
  if [[ -z "$device_type" || -z "$action" ]]; then
    show_help
    return 1
  fi
  
  case "$device_type" in
    "keyboard"|"k")
      switch_device "$KEYBOARD_NAME" "$KEYBOARD_PIN" "$action" "Keyboard" "$BLUE"
      ;;
    "mouse"|"m")
      switch_device "$MOUSE_NAME" "$MOUSE_PIN" "$action" "Mouse" "$GREEN"
      ;;
    "both"|"b")
      echo -e "\n${BOLD}${MAGENTA}Switching Both Devices...${NC}"
      echo -e "${GRAY}Processing keyboard first, then mouse${NC}\n"
      
      switch_device "$KEYBOARD_NAME" "$KEYBOARD_PIN" "$action" "Keyboard" "$BLUE"
      local keyboard_result=$?
      
      echo -e "\n${GRAY}----------------------------------------${NC}"
      
      switch_device "$MOUSE_NAME" "$MOUSE_PIN" "$action" "Mouse" "$GREEN"
      local mouse_result=$?
      
      # Summary
      echo -e "\n${BOLD}${MAGENTA}Summary:${NC}"
      if [[ $keyboard_result -eq 0 ]]; then
        echo -e "  ${GREEN}Keyboard: Success${NC}"
      else
        echo -e "  ${RED}Keyboard: Failed${NC}"
      fi
      
      if [[ $mouse_result -eq 0 ]]; then
        echo -e "  ${GREEN}Mouse: Success${NC}"
      else
        echo -e "  ${RED}Mouse: Failed${NC}"
      fi
      
      [[ $keyboard_result -eq 0 && $mouse_result -eq 0 ]] && return 0 || return 1
      ;;
    *)
      echo -e "${RED}Invalid device type: $device_type${NC}"
      show_help
      return 1
      ;;
  esac
}

function switch_device() {
  local device_name="$1"
  local device_pin="$2"
  local action="$3"
  local device_display="$4"
  local theme_color="$5"
  
  # Find device info - first try paired devices
  local id=$(blueutil --paired | grep "$device_name" | grep -Eo '[a-z0-9]{2}(-[a-z0-9]{2}){5}')
  local name=$(blueutil --paired | grep "$device_name" | grep -Eo 'name: "\S+"')
  
  # If not found in paired devices, search nearby devices via inquiry
  if [[ -z "$id" ]]; then
    echo -e "\n${YELLOW}$device_display not found in paired devices, searching nearby...${NC}"
    id=$(blueutil --inquiry | grep "$device_name" | grep -Eo '[a-z0-9]{2}(-[a-z0-9]{2}){5}')
    name=$(blueutil --inquiry | grep "$device_name" | grep -Eo 'name: "\S+"')
    
    if [[ -z "$id" ]]; then
      echo -e "\n${RED}$device_display not found in paired or nearby devices${NC}"
      echo -e "\t${GRAY}Make sure your $device_display is:${NC}"
      echo -e "\t\t${GRAY}1. Turned on and in pairing mode${NC}"
      echo -e "\t\t${GRAY}2. Within Bluetooth range${NC}"
      echo -e ""
      echo -e "\n${BLUE}Available paired devices:${NC}"
      show_paired_devices
      return 1
    else
      echo -e "\n${GREEN}Found $device_display nearby: $id${NC}"
    fi
  fi
  
  case "$action" in
    "claim"|"c")
      claim_device "$id" "$name" "$device_pin" "$device_display" "$theme_color"
      ;;
    "release"|"r")
      release_device "$id" "$name" "$device_display" "$theme_color"
      ;;
    "status"|"s")
      check_device_status "$id" "$name" "$device_display" "$theme_color"
      ;;
    *)
      echo -e "${RED}Invalid action: $action${NC}"
      show_help
      return 1
      ;;
  esac
}

function claim_device() {
  local id="$1"
  local name="$2"
  local pin="$3"
  local device_display="$4"
  local theme_color="$5"
  
  echo -e "\n${BOLD}${theme_color}Claiming $device_display...${NC}"
  echo -e "\t${GRAY}Device: $id, $name${NC}"
  
  # Check if already connected
  if [[ "$(blueutil --is-connected "$id")" == "1" ]]; then
    echo -e "\n${GREEN}$device_display already connected to this laptop${NC}"
    return 0
  fi
  
  # Check if device is already paired
  if blueutil --paired | grep -q "$id"; then
    echo -e "\n${YELLOW}$device_display already paired, connecting...${NC}"
  else
    echo -e "\n${YELLOW}$device_display not paired, pairing now...${NC}"
    echo -e "\t${GRAY}Waiting for $device_display to enter pairable mode...${NC}"
    sleep 2
    
    echo -e "\n${theme_color}Pairing with this laptop...${NC}"
    if [[ -n "$pin" ]]; then
      blueutil --pair "$id" "$pin"
    else
      blueutil --pair "$id"
    fi
    sleep 2

    if ! blueutil --paired | grep -q "$id"; then
      echo -e "\n${RED}Failed to pair. Make sure $device_display is in pairing mode and try again.${NC}"
      return 1
    fi
  fi
  
  echo -e "\n${theme_color}Connecting...${NC}"
  blueutil --connect "$id"
  
  if [[ "$(blueutil --is-connected "$id")" == "1" ]]; then
    echo -e "\n${BOLD}${GREEN}$device_display successfully claimed and connected!${NC}"
  else
    echo -e "\n${RED}Failed to connect. Try running the command again.${NC}"
    return 1
  fi
}

function release_device() {
  local id="$1"
  local name="$2"
  local device_display="$3"
  local theme_color="$4"
  
  echo -e "\n${BOLD}${YELLOW}Releasing $device_display...${NC}"
  echo -e "\t${GRAY}Device: $id, $name${NC}"
  
  # Check if connected
  if [[ "$(blueutil --is-connected "$id")" == "0" ]]; then
    echo -e "\n${YELLOW}$device_display not currently connected to this laptop${NC}"
  else
    echo -e "\n${theme_color}Disconnecting...${NC}"
    blueutil --unpair "$id"
    echo -e "\n${GREEN}$device_display disconnected and ready for other device${NC}"
  fi
}

function check_device_status() {
  local id="$1"
  local name="$2"
  local device_display="$3"
  local theme_color="$4"
  
  echo -e "\n${BOLD}${theme_color}$device_display Status:${NC}"
  echo -e "\t${GRAY}Device: $id, $name${NC}"
  
  if [[ "$(blueutil --is-connected "$id")" == "1" ]]; then
    echo -e "\n${GREEN}Connected to this laptop${NC}"
  else
    echo -e "\n${YELLOW}Not connected to this laptop${NC}"
  fi
}

function show_paired_devices() {
  blueutil --paired | while read -r line; do
    device_id=$(echo "$line" | grep -Eo '[a-z0-9]{2}(-[a-z0-9]{2}){5}')
    device_name=$(echo "$line" | grep -Eo 'name: "\S+"' | sed 's/name: "//' | sed 's/"//')
    if [[ -n "$device_id" && -n "$device_name" ]]; then
      echo -e "\t${CYAN}$device_id${NC} - ${GRAY}$device_name${NC}"
    fi
  done
}

function show_help() {
  echo -e "${BOLD}${CYAN}Device Switcher${NC}"
  echo -e ""
  echo -e "${BOLD}Usage:${NC} device_switch <device> <action>"
  echo -e ""
  echo -e "${BOLD}Devices:${NC}"
  echo -e "  ${BLUE}keyboard | k${NC}  - Magic Keyboard"
  echo -e "  ${GREEN}mouse | m${NC}     - Magic Mouse"
  echo -e "  ${MAGENTA}both | b${NC}      - Both devices"
  echo -e ""
  echo -e "${BOLD}Actions:${NC}"
  echo -e "  ${GREEN}claim | c${NC}     - Claim device for this laptop (pair & connect)"
  echo -e "  ${YELLOW}release | r${NC}   - Release device (unpair so other laptop can use)"
  echo -e "  ${BLUE}status | s${NC}    - Check current connection status"
  echo -e ""
  echo -e "${BOLD}Examples:${NC}"
  echo -e "  ${GRAY}device_switch keyboard claim${NC}"
  echo -e "  ${GRAY}device_switch k c${NC}"
  echo -e "  ${GRAY}device_switch mouse release${NC}"
  echo -e "  ${GRAY}device_switch m r${NC}"
  echo -e "  ${GRAY}device_switch both status${NC}"
  echo -e "  ${GRAY}device_switch b s${NC}"
  echo -e ""
  echo -e "${BOLD}Device Status Overview:${NC}"
  echo -e "  ${GRAY}device_switch both status${NC}"
}

# Allow calling the function directly if script is executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  device_switch "$1" "$2"
fi