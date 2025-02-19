#!/bin/bash -e

# Main entry-point for flef in the shell. This script must be able to be ran
# normally, or sourced into the terminal. By sourcing this script into the
# terminal, it can change the directory of the shell's current working
# directory. This gets around a limitation in shells which prevents the main
# functionality of flef.

FLEF_INSTALLATION="${FLEF_INSTALLATION:-""}"
if [[ "$BASH_SOURCE" ]] ; then
  FLEF_INSTALLATION="$(cd "$(dirname "$BASH_SOURCE")" && pwd)"
elif [[ "$0" ]] ; then
  FLEF_INSTALLATION="$(cd "$(dirname $0)" && pwd)"
elif [[ -z "$FLEF_INSTALLATION" ]] ; then
  echo "error: Could not determine flef installation directory"
  if [[ ! "$FLEF_USE_SOURCE" ]] ; then
    exit 1
  fi
fi

# If flef does not use source, assume its configuration is not loaded, and
# attempt to find and load it.
#
if [[ -z "$FLEF_USE_SOURCE" ]] ; then
  flef_config_path="$FLEF_INSTALLATION/flef.config.sh"
  if [[ -f "$flef_config_path" ]] ; then
    source "$flef_config_path"
  fi
fi

# Load flef settings

declare -A flef_settings

"$FLEF_INSTALLATION/eval-settings.sh" \ | cut -f2- \
| while IFS=$'\t' read -r key value
do
  flef_settings["$key"]="$value"
done


function flef_get {
  # Gets flef-related information
  
  case $1 in
    installation) echo $FLEF_INSTALLATION     ; test ! -z "$FLEF_INSTALLATION" ;;
    dir)          flef_get setting 'FLEF_DIR' ; return $?                      ;;
    last)         shift ; flef_find_last $@   ; return $?                      ;;
    pwd)          flef_get project "$(pwd)"   ; return $?                      ;;

    date)
      date +"$(flef_get setting FLEF_DATEFORMAT)"
      return $?
      ;;

    setting) shift
      local value="${flef_settings["$1"]}"
      echo "$value"
      test ! -z "$value"
      return $?
      ;;

    project) shift

      # Given the directory at $1, print the root of the flef project directory
      local project_path="$(cd "$2" && pwd)"
      local abs_flef_dir="$(cd "$FLEF_DIR" && pwd)"

      if [[ ! "$project_path" = "$abs_flef_dir"/* ]] ; then
        >&2 echo "error: Directory is not a flef project directory"
        return 1
      fi

      echo "${FLEF_DIR}/$(flef_main get project-name "$2")"
      ;;

    project-name)
      # Given a path at $2, return the name of the project,
      # based off the intersection of that path and $FLEF_DIR.
      # This function does not process symbolic links.

      local project_path="$(cd "$2" && pwd)"
      local abs_flef_dir="$(cd "$FLEF_DIR" && pwd)"

      if [[ ! "$project_path" = "$abs_flef_dir"/* ]] ; then
        >&2 echo "error: Directory is not a flef project directory"
        return 1
      fi

      echo "$project_path" | tail -c "+$(echo "${FLEF_DIR}" | wc -c | tr -d '[:space:]')" | cut -d/ -f2
      return 0
      ;;

    *)
      return 1 ;;
  esac
}


function flef_find {
  # Runs the find command, inside the flef base directory,
  # filtering for directories directly under it, and print
  # their modified dates and names (separated by a tab)

  local flef_dir=$(flef_get dir)

  for directory in $(find "$flef_dir" -mindepth 1 -maxdepth 1 -follow \( -type d -o -type l \) $@); do
    # Because -printf is a flag in GNU find, but not on more
    # BSD-flavored UNIX-like systems such as OSX, manually echo
    # the output. The equivilant GNU find argument for this
    # result is -printf '%T@\t%p\n'
    #
    echo "$(date -r "${directory}" +%s)	${directory}"
  done
  return $?
}


function flef_find_last {
  # Find the last modified flef directory

  local last_offset="${1:-"1"}"

  if [[ ! $last_offset =~ ^[0-9]+$ ]] ; then
    echo "error: command 'flef last [number]' expects number to be a positive integer"
    return 1
  fi

  local recent_project_dir=$(
    flef_find | sort -n | tail -n "$(echo "$last_offset" | tr -d '[:space:]')" | head -n 1 | cut -f2
  )

  if [[ -z $recent_project_dir ]] ; then
    return 1
  fi

  echo "${recent_project_dir}"
}


function flef_get_project_name {
  # Given a path at $1, return the name of the project, based off
  # the intersection of that path and the user's FLEF_DIR.
  # This function does not process symbolic links.

  local flef_dir="$(flef_get dir)"

  if [[ ! $1 = "$flef_dir"/* ]] ; then
    >&2 echo "error: Directory is not a flef project directory"
    return 1
  fi

  echo "$1" | tail -c "+$(echo "${flef_dir}" | wc -c | tr -d '[:space:]')" | cut -d/ -f2
  return 0
}


function flef_get_project_path {
  # Given the directory at $1, print the root of the flef project directory

  local flef_dir="$(flef_get dir)"

  if [[ ! "$1" = "$flef_dir"/* ]] ; then
    >&2 echo "error: Directory is not a flef project directory"
    return 1
  fi

  echo "${flef_dir}/$(flef_get_project_name "$1")"
}


function flef_cd {
  local project_dir="${1}"

  if [[ -z $project_dir ]] ; then
    echo "[flef_cd] error: project directory not defined"
    return 1
  fi

  # If the project directory doesn't exist, create it

  if [[ ! ( -d "$project_dir" || -L "$project_dir") ]] ; then
    mkdir -p "$project_dir"
  fi

  if [ ! $FLEF_USE_SOURCE ] ; then
    echo "Starting a new shell"
  fi

  echo $project_dir
  cd "$project_dir"

  # Look for Python virtual environments

  if [ $FLEF_USE_SOURCE ] ; then
    # If this script is being sourced, directly source the Python virtual
    # environment, if it exists; TODO: add an environment variable flag

    if [[ -d "./venv" ]] ; then 
      source ./venv/bin/activate
    fi

    if [[ -d "./env"  ]] ; then 
      source ./env/bin/activate
    fi
  else
    # Detect Python virtualenv directories, and inject them into the shell;
    # TODO: add an environment variable flag

    VIRTUALENV_EXEC=""

    if [[ -d "./venv" ]] ; then 
      VIRTUALENV_EXEC='source ./venv/bin/activate ;'
    fi

    if [[ -d "./env"  ]] ; then 
      VIRTUALENV_EXEC='source ./env/bin/activate ;'
    fi

    bash -c "$VIRTUALENV_EXEC exec $SHELL"
  fi
}


function flef_rm {
  local flef_dir="$(flef_get dir)"
  local flef_use_source="$(flef_get setting FLEF_USE_SOURCE)"

  local PROJECT_RM_CONFIRM="${PROJECT_RM_CONFIRM:-1}"

  local PROJECT_PATH=$(flef_main get pwd)
  local PROJECT_PATH_STATUS=$?

  if [ $PROJECT_PATH_STATUS != 0 ] ; then
    return $PROJECT_PATH_STATUS
  fi

  if [ $PROJECT_RM_CONFIRM ] ; then
    # Ask a yes or no about deleting, if user says no, exit.
    # The reason for invoking bash, is in case the command
    # is being sourced from a shell other than Bash, which
    # has a different read command, such as Zsh

    echo -n "Delete ${PROJECT_PATH}? [Yn]: "

    if bash -ic 'read -n 1 -r REPLY; [[ ! $REPLY =~ ^[Yy] ]] && [ ! -z $REPLY ]' ; then
      return 0
    fi
  fi

  rm -rf "${PROJECT_PATH}"

  if [ $flef_use_source ] ; then
    cd "$flef_dir"
  else
    return 0
  fi
}


function flef_link {
  local flef_dir="$(flef_get dir)"
  local source_dir="${2:-"$(pwd)"}"
  local project_name="${1:-"$(basename "$source_dir")"}"
  local project_dir="${flef_dir}/$(flef_main get date)_${project_name}"

  ln -s "${source_dir}" "${project_dir}"
  echo "$project_dir"
}


function flef_main {
  # Create the flef directory if it does not exist

  local flef_dir="$(flef_get dir)"

  if [[ ! ( -d "${flef_dir}" || -L "${flef_dir}" ) ]] ; then
    echo "Creating flef directory in $flef_dir"
    mkdir -p "${flef_dir}"
  fi

  case "$1" in
    help) cat "$FLEF_INSTALLATION/usage.txt"      ; return    ;;
    rm)   flef_rm                                 ; return $? ;;
    link) shift ; flef_cd "$(flef_link "$@")"     ; return $? ;;
    sync) shift ; "$FLEF_INSTALLATION/sync.pl" $@ ; return $? ;;
    get)  shift ; flef_get $@                     ; return $? ;;

    last)
      # Find last project directory
      shift

      # do not assign here, in order to capture status:
      #   https://stackoverflow.com/a/50494835
      #
      local last_project_dir
      local last_project_status
      last_project_dir="$(flef_find_last $@)"
      last_project_status=$?

      if [[ $last_project_status -ne 0 ]] ; then
        echo "[flef_find_last] $last_project_dir"
        echo "[flef_main] error: Could not find last project directory"
        return $last_project_status
      fi

      flef_cd "${last_project_dir}"
      return $?
      ;;

    '')
      # Enters the most recently modified flef directory with the current date,
      # and if not found, creates a new one.

      local today_project_dir=$(
        flef_find -name "$(flef_get date)*" | sort -n | tail -n 1 | cut -f2
      )

      if [[ -z "$today_project_dir" ]] ; then
        flef_cd "${flef_dir}/$(flef_get date)"
        return $?
      fi

      flef_cd "${today_project_dir}"
      return $?
      ;;

    *)
      # Use a flef directory with a given name, creating it if needed
      flef_cd "${flef_dir}/$(flef_get date)_${1}"
      ;;
  esac
}

if [[ ! "$(flef_get setting FLEF_USE_SOURCE)" ]] ; then
  flef_main $@
  exit $?
else
  flef_main $@

  # When using source mode, flef's internal function definitions
  # bleed into the user's shell. Without unsetting them, if the
  # user types "flef" and hits tab to auto-complete, all of the
  # functions below will appear.

  unset -f flef_main;
  unset -f flef_find;
  unset -f flef_find_last;
  unset -f flef_get;
  unset -f flef_get_project_path;
  unset -f flef_get_project_name;
  unset -f flef_link;
  unset -f flef_rm;
  unset -f flef_cd;

  unset flef_settings
fi
