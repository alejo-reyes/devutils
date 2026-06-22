#!/bin/zsh

# Usage: ./compare.sh [-s] [-e dir1,dir2,...] <folder1|file1> <folder2|file2>

usage() {
  echo "Usage: $0 [-s] [-e dir1,dir2,...] <folder1|file1> <folder2|file2>"
  echo "  -s: Shallow compare (structure only, no content hashing)"
  echo "  -e: Exclude directories (comma-separated list)"
  exit 1
}

SHALLOW=0
EXCLUDE=""
while getopts ":se:" opt; do
  case "$opt" in
    s) SHALLOW=1 ;;
    e) EXCLUDE="$OPTARG" ;;
    *) usage ;;
  esac
done
shift $((OPTIND - 1))

# Build find exclude patterns
FIND_EXCLUDES=""
if [[ -n "$EXCLUDE" ]]; then
  IFS=',' read -rA exclude_dirs <<< "$EXCLUDE"
  for dir in "${exclude_dirs[@]}"; do
    dir=$(echo "$dir" | xargs)  # trim whitespace
    FIND_EXCLUDES="$FIND_EXCLUDES -not -path \"*/$dir/*\""
  done
fi

if [[ $# -ne 2 ]]; then
  usage
fi

INPUT1=$1
INPUT2=$2

# Resolve full paths
ABS1=$(cd "$(dirname "$INPUT1")" && realpath "$(basename "$INPUT1")")
ABS2=$(cd "$(dirname "$INPUT2")" && realpath "$(basename "$INPUT2")")

# Create temp folder
TMPDIR=$(mktemp -d)
echo "🗂  Temp folder created at: $TMPDIR"
trap '/bin/rm -rf "$TMPDIR"' EXIT

# If both are files, just compare hashes directly
if [[ -f "$ABS1" && -f "$ABS2" ]]; then
  HASH1=$(shasum "$ABS1" | awk '{print $1}')
  HASH2=$(shasum "$ABS2" | awk '{print $1}')

  echo "🔍 Comparing files:"
  echo "  $ABS1"
  echo "  $ABS2"
  echo

  if [[ "$HASH1" == "$HASH2" ]]; then
    echo "✅ The files are identical."
  else
    echo "❌ The files differ."
    echo "  File 1 hash: $HASH1"
    echo "  File 2 hash: $HASH2"
  fi

  exit 0
fi

# Ensure both are directories if not files
if [[ ! -d "$ABS1" || ! -d "$ABS2" ]]; then
  echo "❗ You must provide two files OR two folders."
  exit 1
fi

# Hash and list relative paths for each folder
cd "$ABS1" || exit 1
if (( SHALLOW )); then
  eval "find . -type f $FIND_EXCLUDES | sort" > "$TMPDIR/folder1.txt"
else
  eval "find . -type f $FIND_EXCLUDES -exec shasum {} \\; | sort" > "$TMPDIR/folder1.txt"
fi

cd "$ABS2" || exit 1
if (( SHALLOW )); then
  eval "find . -type f $FIND_EXCLUDES | sort" > "$TMPDIR/folder2.txt"
else
  eval "find . -type f $FIND_EXCLUDES -exec shasum {} \\; | sort" > "$TMPDIR/folder2.txt"
fi

# Create associative arrays: path => hash
typeset -A hashes1 hashes2

if (( SHALLOW )); then
  while IFS= read -r path || [[ -n "$path" ]]; do
    [[ -z "$path" ]] && continue
    hashes1["$path"]="structure-only"
  done < "$TMPDIR/folder1.txt"

  while IFS= read -r path || [[ -n "$path" ]]; do
    [[ -z "$path" ]] && continue
    hashes2["$path"]="structure-only"
  done < "$TMPDIR/folder2.txt"
else
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" ]] && continue
    hash=${line%% *}
    path=${line#"$hash"}
    path=${path## }
    hashes1["$path"]=$hash
  done < "$TMPDIR/folder1.txt"

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" ]] && continue
    hash=${line%% *}
    path=${line#"$hash"}
    path=${path## }
    hashes2["$path"]=$hash
  done < "$TMPDIR/folder2.txt"
fi

# Collect all unique paths
all_paths=("${(@k)hashes1}" "${(@k)hashes2}")
all_paths=("${(@u)all_paths}")  # unique

# Compare
identical=()
added=()
removed=()
modified=()

for path in "${all_paths[@]}"; do
  h1="${hashes1[$path]}"
  h2="${hashes2[$path]}"
  if [[ -n "$h1" && -n "$h2" ]]; then
    if [[ "$h1" == "$h2" ]]; then
      identical+=("$path")
    else
      modified+=("$path")
    fi
  elif [[ -n "$h1" ]]; then
    removed+=("$path")
  elif [[ -n "$h2" ]]; then
    added+=("$path")
  fi
done

# Report
echo "🔍 Comparing folders:"
echo "  Folder 1: $ABS1 ($(find "$ABS1" -type f | wc -l) items)"
echo "  Folder 2: $ABS2 ($(find "$ABS2" -type f | wc -l) items)"
echo

if (( SHALLOW )); then
  echo "ℹ️  Shallow compare: file structure only (no content hashing)."
fi

if [[ -n "$EXCLUDE" ]]; then
  echo "ℹ️  Excluding directories: $EXCLUDE"
fi

if (( SHALLOW )) || [[ -n "$EXCLUDE" ]]; then
  echo
fi

if (( ${#identical[@]} )); then
  echo "✅ Identical files (${#identical[@]}):"
  printf "  %s\n" "${identical[@]}"
  echo
fi

if (( ${#added[@]} )); then
  echo "➕ Added files (only in folder 2) (${#added[@]}):"
  printf "  %s\n" "${added[@]}"
  echo
fi

if (( ${#removed[@]} )); then
  echo "➖ Removed files (only in folder 1) (${#removed[@]}):"
  printf "  %s\n" "${removed[@]}"
  echo
fi

if (( ${#modified[@]} )); then
  echo "🔁 Modified files (${#modified[@]}):"
  printf "  %s\n" "${modified[@]}"
  echo
fi
