#!/bin/bash

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
OUTPUT_JSON=false
SELECT_ONLY=false

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [--json] [--select]
Lists all open Google Chrome windows and tabs on macOS, even when Chrome is not running with remote debugging.

Options:
  --json      Output the tab list as JSON
  --select    Show only the currently selected tab in each window
  -h, --help  Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)
      OUTPUT_JSON=true
      shift
      ;;
    --select)
      SELECT_ONLY=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if ! command -v osascript >/dev/null 2>&1; then
  echo "ERROR: osascript is required but not installed." >&2
  exit 1
fi

# Create temporary AppleScript file
APPLESCRIPT_TMP=$(mktemp)
trap "rm -f $APPLESCRIPT_TMP" EXIT

cat > "$APPLESCRIPT_TMP" << 'APPLE_SCRIPT_CODE'
tell application "System Events"
  set chromeRunning to (name of processes) contains "Google Chrome"
end tell

if not chromeRunning then
  return "ERROR:NOT_RUNNING"
end if

tell application "Google Chrome"
  if (count windows) = 0 then
    return "NO_WINDOWS"
  end if

  set output to ""

  repeat with wIndex from 1 to count windows
    set theWindow to window wIndex
    set selectedTab to (active tab of theWindow)
    
    repeat with tIndex from 1 to count tabs of theWindow
      set theTab to tab tIndex of theWindow
      set tabID to id of theTab
      set titleText to my escapeText(title of theTab)
      set urlText to my escapeText(URL of theTab)
      set isSelected to (theTab is selectedTab)

      set output to output & wIndex & "\t" & tIndex & "\t" & tabID & "\t" & (isSelected as string) & "\t" & titleText & "\t" & urlText & "\n"
    end repeat
  end repeat
end tell

return output

on escapeText(theText)
  set theText to my replaceText(linefeed, " ", theText)
  set theText to my replaceText(return, " ", theText)
  set theText to my replaceText(tab, " ", theText)
  return theText
end escapeText

on replaceText(findStr, replaceStr, textString)
  set AppleScript's text item delimiters to findStr
  set textItems to every text item of textString
  set AppleScript's text item delimiters to replaceStr
  set newText to textItems as string
  set AppleScript's text item delimiters to ""
  return newText
end replaceText
APPLE_SCRIPT_CODE

RAW_OUTPUT=$(osascript "$APPLESCRIPT_TMP" 2>&1)
RESULT=$?

if [[ $RESULT -ne 0 ]]; then
  echo "ERROR: Failed to run AppleScript" >&2
  exit 1
fi

if [[ "$RAW_OUTPUT" == "ERROR:NOT_RUNNING" ]]; then
  echo "Google Chrome is not running." >&2
  exit 1
fi

if [[ "$RAW_OUTPUT" == "NO_WINDOWS" ]]; then
  echo "Google Chrome is running but has no open windows."
  exit 0
fi

if [[ -z "$RAW_OUTPUT" ]]; then
  echo "No Chrome tabs were found." >&2
  exit 1
fi

# Create temporary Python file
PYTHON_TMP=$(mktemp)
trap "rm -f $APPLESCRIPT_TMP $PYTHON_TMP" EXIT

cat > "$PYTHON_TMP" << 'PYTHON_CODE'
import json
import sys

output_json = sys.argv[1].lower() == 'true'
select_only = sys.argv[2].lower() == 'true'
raw_text = sys.stdin.read()

tabs = []
for line in raw_text.splitlines():
    if not line:
        continue
    parts = line.split('\t', 5)
    if len(parts) != 6:
        continue

    window_index, tab_index, tab_id, is_selected, title, url = parts
    try:
        window_index = int(window_index)
        tab_index = int(tab_index)
        tab_id = int(tab_id)
        is_selected = is_selected.lower() == 'true'
    except ValueError:
        continue

    if select_only and not is_selected:
        continue

    tabs.append({
        "windowIndex": window_index,
        "tabIndex": tab_index,
        "tabId": tab_id,
        "isSelected": is_selected,
        "title": title,
        "url": url,
    })

if output_json:
    print(json.dumps(tabs, indent=2, ensure_ascii=False))
else:
    if not tabs:
        print("No Chrome tabs found.")
    else:
        if select_only:
            print("Currently selected tabs:")
            print("=======================")
        else:
            print("Google Chrome tabs:")
            print("===================")
        for tab in tabs:
            window_label = "Window {}".format(tab["windowIndex"])
            tab_label = "Tab {} (ID: {})".format(tab["tabIndex"], tab["tabId"])
            if tab["isSelected"]:
                tab_label += " [SELECTED]"
            print("{} - {}".format(window_label, tab_label))
            print("  Title: {}".format(tab["title"]))
            print("  URL:   {}".format(tab["url"]))
            print()
PYTHON_CODE

echo "$RAW_OUTPUT" | python3 "$PYTHON_TMP" "$OUTPUT_JSON" "$SELECT_ONLY"
