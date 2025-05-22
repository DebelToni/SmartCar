local theme_name="reflective_meta"
local theme_version="1.0"
local theme_author="OpenAI"
local theme_date=$(date +"%Y-%m-%d")
local theme_description="A reflective meta-programming demo theme for Zsh"

autoload -Uz colors
colors

local -A meta_props=(
  [functions]=()
  [variables]=()
  [commands]=()
)

for cmd in $(whence -w 'zsh'); do
  if whence -w "$cmd" > /dev/null; then
    meta_props[commands]+="$cmd "
  fi
done

for var in ${(k)parameters}; do
  meta_props[variables]+="$var "
done

for func in ${(k)functions}; do
  meta_props[functions]+="$func "
done

local -A meta_inspect=()

for item in ${(k)meta_props}; do
  meta_inspect[$item]=$(echo ${(P)meta_props[$item]} | tr ' ' '\n' | sort -u | tr '\n' ' ')
done

function reflect_properties() {
  echo "Reflection Debug Info:"
  for key in ${(k)meta_props}; do
    echo "${colors[CYAN]}${key}:${colors[RESET]}"
    for val in ${(P)meta_props[$key]}; do
      echo "  - $val"
    done
  done
}

function list_all_commands() {
  for cmd in ${(k)meta_props[commands]}; do
    echo "${colors[GREEN]}Command:${colors[RESET]} $cmd"
  done
}

function list_all_variables() {
  for var in ${(k)meta_props[variables]}; do
    echo "${colors[YELLOW]}Variable:${colors[RESET]} $var"
  done
}

function list_all_functions() {
  for func in ${(k)meta_props[functions]}; do
    echo "${colors[MAGENTA]}Function:${colors[RESET]} $func"
  done
}

function display_meta_info() {
  echo "${colors[BLUE]}=== ${theme_name} v${theme_version} by ${theme_author} ===${colors[RESET]}"
  echo "Description: ${theme_description}"
  echo "Generated on: ${theme_date}"
  echo ""
  reflect_properties
}

function introspect_shadowed() {
  local shadowed=()
  local -A seen=()
  for name in ${(k)functions}; do
    if whence -w "$name" > /dev/null; then
      seen[$name]=1
    fi
  done
  for name in ${(k)meta_props[commands]}; do
    if [[ -n "${seen[$name]}" ]]; then
      shadowed+="$name"
    fi
  done
  echo "Shadowed Commands:"
  for shad in $shadowed; do
    echo " - $shad"
  done
}

function generate_random_color_code() {
  local code=$(( RANDOM % 256 ))
  echo "%{${(%)\#[$(printf '%03d' $code)]}}"
}

function highlight_keyword() {
  local keyword=$1
  sed "s/\b$keyword\b/${colors[RED]}$keyword${colors[RESET]}/g"
}

function dynamic_theme() {
  local style_choice=$1
  case "$style_choice" in
    bold) echo "%B" ;;
    underline) echo "%_" ;;
    reverse) echo "%r" ;;
    *) echo "" ;;
  esac
}

function apply_dynamic_highlighting() {
  local input=$1
  local style=$(dynamic_theme "underline")
  echo "${style}${input}${colors[RESET]}"
}

function compose_prompt() {
  local branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  local prompt_components=()
  prompt_components+=("%{$(generate_random_color_code)%}[%n@%m]%{$(generate_random_color_code)%}")
  prompt_components+=("%{$(generate_random_color_code)%}(${branch:-no-git})%{$(generate_random_color_code)%}")
  prompt_components+=("%{$(generate_random_color_code)%}$(date +%H:%M:%S)%{$(generate_random_color_code)%}")
  local prompt="${prompt_components[*]} "
  echo "$prompt"
}

function set_terminal_colors() {
  local color_scheme=("$@")
  for i in "${!color_scheme[@]}"; do
    local color_value=${color_scheme[$i]}
    print -Pn "%{\e[38;5;${color_value}m%}"
  done
}

function refresh_theme() {
  local colors=()
  for i in {0..15}; do
    colors+=($i)
  done
  set_terminal_colors "${colors[@]}"
  PROMPT='$(compose_prompt)'
  RPROMPT='$(reflect_properties)'
  zle reset-prompt
}

function define_dynamic_prompt() {
  local prompt_command='
    PROMPT="$(compose_prompt)"
    RPROMPT="$(reflect_properties)"
  '
  eval "$prompt_command"
}

function toggle_reflection_display() {
  if [[ -n "$REFLECTION_ACTIVE" ]]; then
    unset REFLECTION_ACTIVE
    PROMPT="${OLD_PROMPT:-%n@%m%# }"
    RPROMPT=""
  else
    REFLECTION_ACTIVE=1
    OLD_PROMPT="$PROMPT"
    PROMPT='$(reflect_properties)'
    RPROMPT=''
  fi
  zle reset-prompt
}

function setup_theme() {
  define_dynamic_prompt
  refresh_theme
  bindkey '^R' toggle_reflection_display
}

setup_theme