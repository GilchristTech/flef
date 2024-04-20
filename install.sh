#!/bin/bash

set -eE -o functrace

function failure {
  local line_number=$1
  local message=$2
  echo "Failed at line $line_number: $message"
}
trap 'failure ${LINENO} "$BASH_COMMAND"' ERR

# If HOME is not set, figure it out by expanding ~/
HOME="${HOME:-"$(bash -c 'echo ~/')"}"

function yes-or-no {
  reply=""
  reply="$(bash -ic 'read -n 1 -r reply_subshell; echo "$reply_subshell"')"
  if [[ ! $reply =~ ^[Yy] ]] && [ ! -z $reply ] ; then
    value=1
  fi
  if [[ "$reply" ]] ; then
    echo
  fi
  return 0
}

flef_installation_dir="$(cd "$(dirname "$BASH_SOURCE" )" && pwd)"

flef_config_file=""
if [[ -z "$flef_config_file" ]]; then
  flef_config_file="${flef_installation_dir}/flef.config.sh"
fi

if [[ -f "$flef_config_file" ]] ; then
  echo -n "Configuration file detected at $flef_config_file. Load settings from the existing configuration? [Yn]"

  if yes-or-no ; then
    source "$flef_config_file"
  fi
fi

#
# Determine the shell and its rc file
#

shell_name=""
shell_config_file=""

while true ; do
  shell_name="$(basename $SHELL)"
  read -p "Install on which shell? [$shell_name] " shell_name
  shell_name="${shell_name:-$(basename $SHELL)}"
  shell_config_file=""

  case "$shell_name" in
    "bash") shell_config_file="$HOME/.bashrc" ;;
    "zsh")  shell_config_file="$HOME/.zshrc" ;;
    *) 
      echo "Unsupported shell: $shell_name"
      continue
      ;;
  esac

  break
done

#
# Flef configuration
#

# Ask user for configuration settings, using any currently-set environment
# variables as higher-priority defaults

# Projects directory
#
flef_dir_prompt_value="default: $HOME/flef"
if [[ $FLEF_DIR ]] ; then
  flef_dir_prompt_value="current: $FLEF_DIR"
fi
flef_dir=""
read -p "Projects directory? [$flef_dir_prompt_value] " flef_dir
flef_dir="${flef_dir:-"$FLEF_DIR"}"

# Date format
#
flef_dateformat_prompt_value="default: %y-%m-%d"
if [[ $FLEF_DATEFORMAT ]] ; then
  flef_dateformat_prompt_value="current: $FLEF_DATEFORMAT"
fi
flef_dateformat=""
read -p "Date format ('man date' for reference)? [$flef_dateformat_prompt_value] " flef_dateformat
flef_dateformat="${flef_dateformat:-"$FLEF_DATEFORMAT"}"

# Source mode
#
flef_use_source_prompt_value="default: true"
if [[ "$FLEF_USE_SOURCE" ]] || (grep -q 'FLEF_USE_SOURCE' "$flef_config_file") ; then
  flef_use_source_prompt_value="current: true"
fi
flef_use_source=""

echo -n "Use source mode? ($flef_use_source_prompt_value) [Yn] "
if yes-or-no ; then
  flef_use_source=true
fi

function flef-generate-config {
  if [[ "$flef_dir" ]] ; then
    echo "export FLEF_DIR=\"${flef_dir}\""
  fi

  if [[ "$flef_dateformat" ]] ; then
    echo "export FLEF_DATEFORMAT=\"${flef_dateformat}\""
  fi

  if [[ "$flef_use_source" ]] ; then
    echo "alias flef='FLEF_USE_SOURCE=1 source \"${flef_installation_dir}/flef.sh\"'"
  fi
}

# Look for an existing flef configuration, or generate
# the contents for one

flef_config_content="$(test ! -f "$flef_config_file" || cat "$flef_config_file")"
if [[ -f "$flef_config_file" ]] ; then
  echo "Found existing flef configuration at ${flef_config_file}"
  echo -n "Overwrite with new settings? [Yn] "
  if yes-or-no ; then
    flef_config_content="$(flef-generate-config)"
    echo "#!/bin/bash" > "$flef_config_file"
    echo "$flef_config_content" >> "$flef_config_file"
  fi
else
  echo "Generating config file at ${flef_config_file}"
  flef_config_content="$(flef-generate-config)"
  if [[ "$flef_config_content" ]] ; then
    echo "#!/bin/bash" > "$flef_config_file"
    echo "$flef_config_content" >> "$flef_config_file"
  fi
fi
chmod +x "$flef_config_file"

#
# Shell configuration
#

# Ensure the shell configuration sources the flef configuration

if [[ "$flef_config_content" ]] ; then
  # Check if the shell configuration sources a flef config file.
  # If not, append a source line.

  if ! grep -qE '^(source|\.) .*flef.config.sh(\s|$|"|'\'')' "$shell_config_file" ; then
    echo "Updating $shell_config_file"
    echo >> "$shell_config_file"
    echo "# Source flef configuration" >> "$shell_config_file"
    echo "source \"${flef_installation_dir}/flef.config.sh\"" >> "$shell_config_file"
  fi
else
  echo "Flef appears to be using default options, so no changes to the shell configuration are being made."
fi


# Handle user's local bin flef installation,
# if not using source-based invocation of flef

if ! echo "$flef_config_content" | grep -q "FLEF_USE_SOURCE" ; then
  # Ensure "$HOME/.local/bin" is in $PATH and exists
  mkdir -p "$HOME/.local/bin"
  if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    echo >> "$shell_config_file"
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$shell_config_file"
  fi

  # symlink flef in the local bin to the bash scr
  if [[ ! -f "$HOME/.local/bin/flef" ]] ; then
    ln -s "$flef_installation_dir/flef.sh" "$HOME/.local/bin/flef"
  fi
fi
