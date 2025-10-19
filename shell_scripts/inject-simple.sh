#!/bin/bash

# Chrome DevTools Script Injector
# Combined functionality: Start Chrome in debug mode + Inject scripts
# Handles Chrome startup, tab management, and script injection

set -e

# Configuration
CHROME_DEBUG_PORT=9222
BASE_URL="http://localhost:${CHROME_DEBUG_PORT}"
SCRIPTS_DIR="$(dirname "$0")"
# Use a persistent debug profile instead of temporary
CHROME_USER_DATA_DIR="$HOME/.chrome-debug-profile"
DEFAULT_URL="http://localhost:4173"

echo "Chrome DevTools Script Injector"
echo "==============================="

# Function to check if Chrome debug is running
check_chrome_debug() {
    if curl -s "${BASE_URL}/json/version" > /dev/null 2>&1; then
        echo "Chrome debug mode is running on port ${CHROME_DEBUG_PORT}"
        return 0
    else
        echo "Chrome debug mode not found on port ${CHROME_DEBUG_PORT}"
        return 1
    fi
}

# Function to setup Chrome debug profile
setup_debug_profile() {
    if [ ! -d "$CHROME_USER_DATA_DIR" ]; then
        echo "Creating persistent Chrome debug profile at: $CHROME_USER_DATA_DIR"
        mkdir -p "$CHROME_USER_DATA_DIR"
        
        # Create a basic preferences file to skip first-run setup
        mkdir -p "$CHROME_USER_DATA_DIR/Default"
        cat > "$CHROME_USER_DATA_DIR/Default/Preferences" << 'EOF'
{
   "browser": {
      "check_default_browser": false
   },
   "distribution": {
      "import_bookmarks": false,
      "import_history": false,
      "import_search_engine": false,
      "make_chrome_default_for_user": false,
      "skip_first_run_ui": true
   },
   "first_run_tabs": [ "about:blank" ],
   "homepage": "about:blank",
   "homepage_is_newtabpage": false,
   "browser.show_home_button": false,
   "sync_promo": {
      "show_on_first_run_allowed": false
   }
}
EOF
        
        # Create First Run file to skip setup
        touch "$CHROME_USER_DATA_DIR/First Run"
        
        echo "Debug profile created and configured to skip first-run setup"
    else
        echo "Using existing Chrome debug profile: $CHROME_USER_DATA_DIR"
    fi
}

# Function to start Chrome in debug mode
start_chrome_debug() {
    local url="${1:-$DEFAULT_URL}"
    local profile_name="${2:-Default}"
    
    echo "Starting Chrome in debug mode..."
    echo "Port: ${CHROME_DEBUG_PORT}"
    echo "Profile: ${CHROME_USER_DATA_DIR}"
    echo "Chrome Profile: ${profile_name}"
    echo "URL: ${url}"
    
    # Setup the debug profile first
    setup_debug_profile
    
    # Start Chrome with debug flags and profile selection
    # Redirect all output to /dev/null and run in background with nohup
    nohup /Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \
        --remote-debugging-port=${CHROME_DEBUG_PORT} \
        --user-data-dir="${CHROME_USER_DATA_DIR}" \
        --profile-directory="${profile_name}" \
        --disable-web-security \
        --disable-features=VizDisplayCompositor \
        --no-first-run \
        --no-default-browser-check \
        --disable-default-apps \
        --disable-background-mode \
        --disable-background-timer-throttling \
        --disable-backgrounding-occluded-windows \
        --disable-renderer-backgrounding \
        --disable-component-update \
        --disable-sync \
        "${url}" > /dev/null 2>&1 &
    
    local chrome_pid=$!
    echo "Chrome started with PID: ${chrome_pid}"
    
    # Disown the process so it's not tied to the shell
    disown
    
    # Wait for Chrome to be ready
    echo "Waiting for Chrome to be ready..."
    local attempts=0
    local max_attempts=15
    
    while [ $attempts -lt $max_attempts ]; do
        if curl -s "${BASE_URL}/json/version" > /dev/null 2>&1; then
            echo "Chrome debug interface is ready!"
            echo "Terminal is now free - Chrome is running independently"
            return 0
        fi
        
        echo "Attempt $((attempts + 1))/${max_attempts} - waiting..."
        sleep 1
        attempts=$((attempts + 1))
    done
    
    echo "ERROR: Chrome debug interface not ready after ${max_attempts} attempts"
    return 1
}

# Function to ensure Chrome debug is running
ensure_chrome_debug() {
    if ! check_chrome_debug; then
        echo "Starting Chrome in debug mode..."
        start_chrome_debug "$1"
    fi
}

# Function to get debug info
get_debug_info() {
    echo "Chrome Debug Information:"
    echo "========================"
    
    if ! check_chrome_debug; then
        echo "ERROR: Chrome debug interface not available"
        return 1
    fi
    
    echo "Version info:"
    curl -s "${BASE_URL}/json/version" | python3 -m json.tool 2>/dev/null || curl -s "${BASE_URL}/json/version"
    
    echo
    echo "Active tabs:"
    curl -s "${BASE_URL}/json" | python3 -m json.tool 2>/dev/null || curl -s "${BASE_URL}/json"
}

# Function to create a new tab
create_tab() {
    local url="${1:-about:blank}"
    echo "Creating new tab with URL: $url"
    
    ensure_chrome_debug "$url"
    
    local response
    if response=$(curl -s -X PUT "${BASE_URL}/json/new?${url}"); then
        echo "Tab created:"
        echo "$response" | python3 -m json.tool 2>/dev/null || echo "$response"
        return 0
    else
        echo "ERROR: Failed to create tab"
        return 1
    fi
}

# Function to list all tabs
list_tabs() {
    echo "Active tabs:"
    echo "============"
    
    ensure_chrome_debug
    
    local tabs_json
    if tabs_json=$(curl -s "${BASE_URL}/json"); then
        echo "$tabs_json" | python3 -m json.tool 2>/dev/null || echo "$tabs_json"
        return 0
    else
        echo "ERROR: Failed to get tabs"
        return 1
    fi
}

# Function to resolve tab identifier (tab-id or tab-index) to tab-id
resolve_tab_id() {
    local tab_identifier="$1"
    
    if [ -z "$tab_identifier" ]; then
        echo "ERROR: Tab identifier required" >&2
        return 1
    fi
    
    # Don't call ensure_chrome_debug here as it prints messages
    # Just check if Chrome is running and get tabs
    if ! curl -s "${BASE_URL}/json/version" > /dev/null 2>&1; then
        echo "ERROR: Chrome debug interface not available" >&2
        return 1
    fi
    
    local tabs_json
    if tabs_json=$(curl -s "${BASE_URL}/json"); then
        # Use Python to resolve tab identifier to tab ID
        echo "$tabs_json" | python3 -c "
import json
import sys
import re

try:
    tabs = json.load(sys.stdin)
    identifier = '${tab_identifier}'
    
    # Check if identifier is a number (tab index)
    if identifier.isdigit():
        tab_index = int(identifier) - 1  # Convert to 0-based index
        if 0 <= tab_index < len(tabs):
            tab_id = tabs[tab_index].get('id', '')
            if tab_id:
                print(tab_id)
                sys.exit(0)
        print('ERROR: Tab index ${tab_identifier} is out of range (1-' + str(len(tabs)) + ')', file=sys.stderr)
        sys.exit(1)
    else:
        # Assume it's a tab ID, verify it exists
        for tab in tabs:
            if tab.get('id') == identifier:
                print(identifier)
                sys.exit(0)
        print('ERROR: Tab ID ${tab_identifier} not found', file=sys.stderr)
        sys.exit(1)
        
except Exception as e:
    print(f'ERROR: Failed to resolve tab identifier: {e}', file=sys.stderr)
    sys.exit(1)
" 2>/dev/null
    else
        echo "ERROR: Failed to get tabs" >&2
        return 1
    fi
}

# Function to get tab WebSocket URL by tab ID
get_tab_websocket_url() {
    local tab_id="$1"
    
    if [ -z "$tab_id" ]; then
        echo "ERROR: Tab ID required" >&2
        return 1
    fi
    
    # Don't call ensure_chrome_debug here as it prints messages
    # Just check if Chrome is running and get tabs
    if ! curl -s "${BASE_URL}/json/version" > /dev/null 2>&1; then
        echo "ERROR: Chrome debug interface not available" >&2
        return 1
    fi
    
    local tabs_json
    if tabs_json=$(curl -s "${BASE_URL}/json"); then
        # Extract WebSocket URL for the specific tab ID
        echo "$tabs_json" | python3 -c "
import json
import sys
try:
    tabs = json.load(sys.stdin)
    for tab in tabs:
        if tab.get('id') == '${tab_id}':
            ws_url = tab.get('webSocketDebuggerUrl', '')
            if ws_url:
                print(ws_url)
                sys.exit(0)
    print('ERROR: Tab ID ${tab_id} not found', file=sys.stderr)
    sys.exit(1)
except Exception as e:
    print(f'ERROR: Failed to parse tabs JSON: {e}', file=sys.stderr)
    sys.exit(1)
" 2>/dev/null
    else
        echo "ERROR: Failed to get tabs" >&2
        return 1
    fi
}

# Function to execute JavaScript in a specific tab
execute_javascript() {
    local tab_id="$1"
    local javascript="$2"
    
    if [ -z "$tab_id" ] || [ -z "$javascript" ]; then
        echo "ERROR: Tab ID and JavaScript code required"
        return 1
    fi
    
    echo "Executing JavaScript in tab: $tab_id"
    echo "Code: $javascript"
    echo "================================"
    
    # First, we need to create a WebSocket connection to enable Runtime domain
    # Then send the Runtime.evaluate command
    # For HTTP-only approach, we'll use a temporary WebSocket connection via a Python helper
    
    local ws_url
    if ! ws_url=$(get_tab_websocket_url "$tab_id"); then
        echo "ERROR: Could not get tab WebSocket URL"
        return 1
    fi
    
    if [ -z "$ws_url" ]; then
        echo "ERROR: Could not get WebSocket URL for tab $tab_id"
        return 1
    fi
    
    # Use Python to handle WebSocket communication
    local response
    response=$(python3 -c "
import json
import asyncio
import websockets
import sys

async def execute_js():
    try:
        uri = '${ws_url}'
        
        async with websockets.connect(uri) as websocket:
            # Enable Runtime domain
            enable_cmd = {
                'id': 1,
                'method': 'Runtime.enable'
            }
            await websocket.send(json.dumps(enable_cmd))
            
            # Wait for enable response
            while True:
                response = await websocket.recv()
                msg = json.loads(response)
                if msg.get('id') == 1:  # Our enable command response
                    break
            
            # Execute JavaScript
            eval_cmd = {
                'id': 2,
                'method': 'Runtime.evaluate',
                'params': {
                    'expression': $(printf '%s' "$javascript" | python3 -c "import json, sys; print(json.dumps(sys.stdin.read().strip()))"),
                    'returnByValue': True,
                    'generatePreview': True,
                    'includeCommandLineAPI': True,
                    'userGesture': True,
                    'awaitPromise': False
                }
            }
            
            await websocket.send(json.dumps(eval_cmd))
            
            # Wait for evaluation response
            while True:
                response = await websocket.recv()
                msg = json.loads(response)
                if msg.get('id') == 2:  # Our evaluation command response
                    print(json.dumps(msg, indent=2))
                    break
            
    except Exception as e:
        print(json.dumps({'error': {'message': str(e)}}), file=sys.stderr)
        sys.exit(1)

asyncio.run(execute_js())
")
    
    if [ $? -eq 0 ]; then
        # Parse and format the response
        format_execution_result "$response"
        return 0
    else
        echo "ERROR: Failed to execute JavaScript"
        echo "$response"
        return 1
    fi
}

# Function to format execution results
format_execution_result() {
    local response="$1"
    
    echo "Execution Result:"
    echo "================"
    
    # Use Python to parse and format the JSON response
    echo "$response" | python3 -c "
import json
import sys

try:
    data = json.load(sys.stdin)
    
    # Handle WebSocket response format
    if 'error' in data:
        error = data['error']
        if isinstance(error, dict):
            print('Protocol Error:', error.get('message', 'Unknown error'))
        else:
            print('ERROR:', error)
        sys.exit(1)
    
    # Get the result from WebSocket response
    if 'result' in data:
        eval_result = data['result']
        
        if 'exceptionDetails' in eval_result:
            exception = eval_result['exceptionDetails']
            print('JavaScript Error:')
            print('  Exception:', exception.get('text', 'Unknown exception'))
            if 'lineNumber' in exception:
                print(f'  Line: {exception[\"lineNumber\"]}')
            if 'columnNumber' in exception:
                print(f'  Column: {exception[\"columnNumber\"]}')
            if 'exception' in exception and 'description' in exception['exception']:
                print('  Details:', exception['exception']['description'])
        elif 'result' in eval_result:
            value = eval_result['result']
            if value.get('type') == 'undefined':
                print('Result: undefined')
            elif 'value' in value:
                print('Result:', json.dumps(value['value'], indent=2))
            elif 'description' in value:
                print('Result:', value['description'])
            else:
                print('Result type:', value.get('type', 'unknown'))
                if 'preview' in value:
                    print('Preview:', value['preview'].get('description', 'No preview'))
                else:
                    print('Value:', json.dumps(value, indent=2))
        else:
            print('No result returned from evaluation')
    else:
        print('Invalid response format')
        print('Raw response:', json.dumps(data, indent=2))
        
except json.JSONDecodeError as e:
    print('ERROR: Invalid JSON response:', e)
    print('Raw response:')
    print(sys.stdin.read())
except Exception as e:
    print('ERROR: Failed to parse result:', e)
    import traceback
    traceback.print_exc()
"
}

# Function to inject JavaScript inline
inject_inline() {
    local tab_identifier="$1"
    local javascript="$2"
    
    if [ -z "$tab_identifier" ] || [ -z "$javascript" ]; then
        echo "ERROR: Usage: inject <tab-id|tab-index> '<javascript-code>'"
        echo "       Tab identifier can be either a tab ID or tab index (1-based)"
        return 1
    fi
    
    # Resolve tab identifier to tab ID
    local tab_id
    if ! tab_id=$(resolve_tab_id "$tab_identifier"); then
        echo "ERROR: Could not resolve tab identifier: $tab_identifier"
        return 1
    fi
    
    echo "Resolved tab identifier '$tab_identifier' to tab ID: $tab_id"
    execute_javascript "$tab_id" "$javascript"
}

# Function to inject JavaScript from file
inject_file() {
    local tab_identifier="$1"
    local script_file="$2"
    
    if [ -z "$tab_identifier" ] || [ -z "$script_file" ]; then
        echo "ERROR: Usage: inject-file <tab-id|tab-index> <script-file>"
        echo "       Tab identifier can be either a tab ID or tab index (1-based)"
        return 1
    fi
    
    if [ ! -f "$script_file" ]; then
        echo "ERROR: Script file not found: $script_file"
        return 1
    fi
    
    # Resolve tab identifier to tab ID
    local tab_id
    if ! tab_id=$(resolve_tab_id "$tab_identifier"); then
        echo "ERROR: Could not resolve tab identifier: $tab_identifier"
        return 1
    fi
    
    echo "Resolved tab identifier '$tab_identifier' to tab ID: $tab_id"
    echo "Loading JavaScript from: $script_file"
    local javascript
    if javascript=$(cat "$script_file"); then
        execute_javascript "$tab_id" "$javascript"
    else
        echo "ERROR: Failed to read script file: $script_file"
        return 1
    fi
}

# Function to inject JavaScript from stdin
inject_stdin() {
    local tab_identifier="$1"
    
    if [ -z "$tab_identifier" ]; then
        echo "ERROR: Usage: inject-stdin <tab-id|tab-index>"
        echo "       Tab identifier can be either a tab ID or tab index (1-based)"
        echo "       echo 'console.log(\"test\")' | $0 inject-stdin <tab-id|tab-index>"
        return 1
    fi
    
    # Resolve tab identifier to tab ID
    local tab_id
    if ! tab_id=$(resolve_tab_id "$tab_identifier"); then
        echo "ERROR: Could not resolve tab identifier: $tab_identifier"
        return 1
    fi
    
    echo "Resolved tab identifier '$tab_identifier' to tab ID: $tab_id"
    echo "Reading JavaScript from stdin..."
    local javascript
    if javascript=$(cat); then
        if [ -z "$javascript" ]; then
            echo "ERROR: No JavaScript code provided via stdin"
            return 1
        fi
        execute_javascript "$tab_id" "$javascript"
    else
        echo "ERROR: Failed to read from stdin"
        return 1
    fi
}

# Function to find tabs by URL pattern
find_tab_by_pattern() {
    local url_pattern="$1"
    
    if [ -z "$url_pattern" ]; then
        echo "ERROR: Usage: find-tab <url-pattern>"
        return 1
    fi
    
    echo "Finding tabs matching pattern: $url_pattern"
    echo "=========================================="
    
    ensure_chrome_debug
    
    local tabs_json
    if tabs_json=$(curl -s "${BASE_URL}/json"); then
        echo "$tabs_json" | python3 -c "
import json
import sys
import re

try:
    tabs = json.load(sys.stdin)
    pattern = '${url_pattern}'
    matches = []
    
    for tab in tabs:
        url = tab.get('url', '')
        title = tab.get('title', '')
        tab_id = tab.get('id', '')
        
        if re.search(pattern, url, re.IGNORECASE):
            matches.append({
                'id': tab_id,
                'title': title,
                'url': url
            })
    
    if matches:
        print(f'Found {len(matches)} matching tab(s):')
        for i, match in enumerate(matches, 1):
            print(f'  {i}. ID: {match[\"id\"]}')
            print(f'     Title: {match[\"title\"]}')
            print(f'     URL: {match[\"url\"]}')
            print()
    else:
        print('No tabs found matching pattern:', pattern)
        
except Exception as e:
    print('ERROR: Failed to search tabs:', e, file=sys.stderr)
    sys.exit(1)
"
    else
        echo "ERROR: Failed to get tabs"
        return 1
    fi
}

# Function to show enhanced tab listing with cleaner format
show_tabs() {
    echo "Active tabs (for injection):"
    echo "==========================="
    
    ensure_chrome_debug
    
    local tabs_json
    if tabs_json=$(curl -s "${BASE_URL}/json"); then
        echo "$tabs_json" | python3 -c "
import json
import sys

try:
    tabs = json.load(sys.stdin)
    
    if not tabs:
        print('No active tabs found')
        sys.exit(0)
    
    for i, tab in enumerate(tabs, 1):
        tab_id = tab.get('id', 'unknown')
        title = tab.get('title', 'No title')
        url = tab.get('url', 'No URL')
        
        print(f'{i}. Tab ID: {tab_id}')
        print(f'   Title: {title[:60]}...' if len(title) > 60 else f'   Title: {title}')
        print(f'   URL: {url}')
        print()
        
except Exception as e:
    print('ERROR: Failed to parse tabs:', e, file=sys.stderr)
    sys.exit(1)
"
        return 0
    else
        echo "ERROR: Failed to get tabs"
        return 1
    fi
}

# Function to list available Chrome profiles
list_chrome_profiles() {
    echo "Available Chrome profiles:"
    echo "========================="
    
    local chrome_dir="$HOME/Library/Application Support/Google/Chrome"
    
    if [ ! -d "$chrome_dir" ]; then
        echo "Chrome directory not found at: $chrome_dir"
        echo "Make sure Chrome is installed and has been run at least once."
        return 1
    fi
    
    echo "Location: $chrome_dir"
    echo
    
    # List profile directories
    local profile_count=0
    local profiles=()
    
    if [ -d "$chrome_dir/Default" ]; then
        echo "• Default"
        profiles+=("Default")
        profile_count=$((profile_count + 1))
    fi
    
    for profile_dir in "$chrome_dir"/Profile*; do
        if [ -d "$profile_dir" ]; then
            local profile_name=$(basename "$profile_dir")
            echo "• $profile_name"
            profiles+=("$profile_name")
            profile_count=$((profile_count + 1))
        fi
    done
    
    if [ $profile_count -eq 0 ]; then
        echo "No Chrome profiles found."
        echo "Create a new profile in Chrome first."
        return 1
    fi
    
    echo
    echo "Found $profile_count profile(s)"
    echo
    echo "Usage Instructions:"
    echo "=================="
    echo "To start Chrome with a specific profile, use:"
    echo
    echo "  npm run devtools:start -- \"\" \"<profile-name>\""
    echo
    echo "Examples:"
    for profile in "${profiles[@]}"; do
        echo "  npm run devtools:start -- \"\" \"$profile\""
    done
    echo
    echo "To use a custom URL with a profile:"
    echo "  npm run devtools:start -- \"http://localhost:5173\" \"<profile-name>\""
    echo
    echo "Note: The first empty string (\"\") uses the default URL (${DEFAULT_URL})"
}

# Main execution
case "${1:-help}" in
    "start")
        start_chrome_debug "$2" "$3"
        ;;
    "profiles")
        list_chrome_profiles
        ;;
    "check")
        check_chrome_debug
        ;;
    "info")
        get_debug_info
        ;;
    "create-tab")
        create_tab "$2"
        ;;
    "list")
        list_tabs
        ;;
    "tabs")
        show_tabs
        ;;
    "inject")
        inject_inline "$2" "$3"
        ;;
    "inject-file")
        inject_file "$2" "$3"
        ;;
    "inject-stdin")
        inject_stdin "$2"
        ;;
    "find-tab")
        find_tab_by_pattern "$2"
        ;;
    "help"|"--help")
        echo "Usage: $0 [command] [args...]"
        echo ""
        echo "Chrome Management Commands:"
        echo "  start [url] [profile]    - Start Chrome in debug mode with optional profile"
        echo "                             (default url: ${DEFAULT_URL}, default profile: Default)"
        echo "  profiles                 - List available Chrome profiles with usage examples"
        echo "  check                    - Check if Chrome debug is running"
        echo "  info                     - Show Chrome debug information"
        echo "  create-tab [url]         - Create new tab (default: about:blank)"
        echo "  list                     - List all active tabs (detailed JSON)"
        echo "  tabs                     - List active tabs (clean format for injection)"
        echo ""
        echo "Script Injection Commands:"
        echo "  inject <tab-id|index> '<js-code>'           - Inject JavaScript inline"
        echo "  inject-file <tab-id|index> <script-file>    - Inject JavaScript from file"
        echo "  inject-stdin <tab-id|index>                 - Inject JavaScript from stdin"
        echo "  find-tab <url-pattern>                      - Find tabs by URL pattern"
        echo ""
        echo "Tab Identifier Format:"
        echo "  Tab identifiers can be either:"
        echo "  - Tab ID (e.g., 'page_1', '12345')"
        echo "  - Tab index (1-based, e.g., '1', '2', '3')"
        echo ""
        echo "Examples:"
        echo "  # Chrome management"
        echo "  $0 start"
        echo "  $0 start http://localhost:5173"
        echo "  $0 start \"\" \"Profile 1\""
        echo "  $0 start http://localhost:5173 \"Profile 2\""
        echo "  $0 profiles"
        echo "  $0 tabs"
        echo "  $0 create-tab http://localhost:5173"
        echo ""
        echo "  # Script injection using tab ID"
        echo "  $0 inject page_1 'console.log(\"Hello from script!\")'"
        echo "  $0 inject-file page_1 ./debug-helpers.js"
        echo "  echo 'console.log(window.location.href)' | $0 inject-stdin page_1"
        echo ""
        echo "  # Script injection using tab index (1-based)"
        echo "  $0 inject 1 'console.log(\"First tab!\")'"
        echo "  $0 inject 2 'window.debugMode = true'"
        echo "  $0 inject-file 3 ./scene-operations.js"
        echo "  echo 'showSceneTree()' | $0 inject-stdin 1"
        echo ""
        echo "  # Tab management"
        echo "  $0 find-tab localhost"
        echo "  $0 find-tab 5173"
        ;;
    *)
        echo "Unknown command: $1"
        echo "Use '$0 help' for usage information"
        exit 1
        ;;
esac