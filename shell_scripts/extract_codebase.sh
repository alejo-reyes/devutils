#!/bin/zsh

usage() {
  echo "Usage: $0 [--ex dir_or_path1,dir_or_path2,...] <source_path> [output_path_or_name]"
  exit 1
}

default_excludes=("node_modules" "build" ".next" "dist" ".git")
exclude_dirs=()
positional=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ex)
      shift || usage
      IFS=',' read -r -A new_excludes <<< "$1"
      for ex in "${new_excludes[@]}"; do
        [[ -n "$ex" ]] && exclude_dirs+=("$ex")
      done
      shift
      ;;
    --ex=*)
      value="${1#--ex=}"
      IFS=',' read -r -A new_excludes <<< "$value"
      for ex in "${new_excludes[@]}"; do
        [[ -n "$ex" ]] && exclude_dirs+=("$ex")
      done
      shift
      ;;
    -*)
      usage
      ;;
    *)
      positional+=("$1")
      shift
      ;;
  esac
done

if [[ ${#positional[@]} -lt 1 || ${#positional[@]} -gt 2 ]]; then
  usage
fi

src_path="${positional[1]}"
timestamp=$(date +%F_%H-%M)

if [[ ${#positional[@]} -eq 2 ]]; then
  output_arg="${positional[2]}"
  if [[ -d "$output_arg" || "$output_arg" == */ ]]; then
    dir="${output_arg%/}"
    [[ -z "$dir" ]] && dir="/"
    output_file="${dir}/codebase_${timestamp}.txt"
  else
    trimmed="${output_arg%/}"
    trimmed="${trimmed%.txt}"
    output_file="${trimmed}_${timestamp}.txt"
  fi
else
  output_file="$(pwd)/codebase_${timestamp}.txt"
fi

echo "Interpret sections as '=== <path> ===' headers followed by exact file contents." > "$output_file"
find_args=(
  "$src_path" -type f
  \( -name "*.tsx" -o -name "*.ts" -o -name "*.jsx" -o -name "*.js" -o -name "*.css" -o -name "*.ms" -o -name "*.mcr" -o -name "*.osl" \)
)

add_exclude() {
  local ex="$1"
  ex="${ex%/}"
  if [[ "$ex" == *"/"* ]]; then
    if [[ "$ex" == /* ]]; then
      find_args+=(-not -path "$ex" -not -path "$ex/*")
    else
      find_args+=(-not -path "$src_path/$ex" -not -path "$src_path/$ex/*")
    fi
  else
    find_args+=(-not -path "*/${ex}/*")
  fi
}

for ex in "${default_excludes[@]}"; do
  add_exclude "$ex"
done

for ex in "${exclude_dirs[@]}"; do
  add_exclude "$ex"
done

find "${find_args[@]}" -exec echo "=== {} ===" \; -exec cat {} \; >> "$output_file"

echo "✅ Codebase saved to $output_file"
