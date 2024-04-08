#!/bin/bash -e

flef_installation_dir="$(cd "$(dirname "$BASH_SOURCE" )" && pwd)"

flef_config_file=""
if [[ -z "$flef_config_file" ]]; then
  flef_config_file="${flef_installation_dir}/flef.config.sh"
fi

shell_name="$(basename "$SHELL")"
shell_config_file=""
case "$shell_name" in
    "bash") shell_config_file="$HOME/.bashrc" ;;
    "zsh")  shell_config_file="$HOME/.zshrc" ;;
    *) 
        echo "Unsupported shell: $shell_name"
        exit 1
        ;;
esac


function flef-generate-config {
  if [[ "$FLEF_DIR" ]] ; then
    echo "export FLEF_DIR=\"${FLEF_DIR}\""
  fi

  if [[ "$FLEF_DATEFORMAT" ]] ; then
    echo "export FLEF_DATEFORMAT=\"${FLEF_DATEFORMAT}\""
  fi

  if [[ "$FLEF_USE_SOURCE" ]] ; then
    echo "alias flef='FLEF_USE_SOURCE=1 source \"${flef_installation_dir}/flef.sh\"'"
  fi
}


# Look for an existing flef configuration, or generate
# the contents for one

flef_config_content=""
if [[ -f "$flef_config_file" ]] ; then
  echo "Using existing config file at ${flef_config_file}"
  flef_config_content="$(cat "$flef_config_file")"
else
  echo "Generating config file at ${flef_config_file}"
  flef_config_content="$(flef-generate-config)"
fi

# Write the flef configuration file, and ensure the shell
# configuration sources it

if [[ "$flef_config_content" ]] ; then
  echo "$flef_config_content" > "$flef_config_file"
  chmod +x "$flef_config_file"

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
