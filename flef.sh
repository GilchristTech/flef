#!/usr/bin/bash -e

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

FLEF_DIR="${FLEF_DIR:-"$HOME/flef"}"
FLEF_DATEFORMAT="${FLEF_DATEFORMAT:-%y-%m-%d}"


FLEF_USAGE=$(cat <<EOF
Usage: flef [project_name|last [n]|help]
  no arguments        Go to the last project from today, or create a new one

  project_name        Create a project directory with the provided name
                      (e.g., flef my-project)

  last [n]            Move into the last modified flef directory, optionally
                      selecting the Nth most recent directory

  link [name?] [dir?] Create a flef project as a symbolic link to another
                      directory, with an optional name. If no arguments are
                      specified, the current directory and its name are used.

  sync [push|pull]    Uploads/downloads projects to remote hosts with SSH and
                      rsync

  get [item]          Gets flef-related data and configuration as strings.
                      Available items:
                        installation, dir, pwd, last [n?], date,
                        project, project-name

  help                Show this usage outline
EOF
)


function flef-get {
  # Gets flef-related information
  
  case $1 in
    installation) echo $FLEF_INSTALLATION     ; test ! -z "$FLEF_INSTALLATION" ;;
    dir)          echo $FLEF_DIR              ; test ! -z "$FLEF_DIR"          ;;
    last)         shift ; flef-find-last $@   ; return $?                      ;;
    date)         date +"${FLEF_DATEFORMAT}"  ; return $?                      ;;
    pwd)          flef-get project "$(pwd)"   ; return $?                      ;;

    project)
      shift
      # Given the directory at $1, print the root of the flef project directory
      local project_path="$(cd "$2" && pwd)"
      local abs_flef_dir="$(cd "$FLEF_DIR" && pwd)"

      if [[ ! "$project_path" = "$abs_flef_dir"/* ]] ; then
        >&2 echo "error: Directory is not a flef project directory"
        return 1
      fi

      echo "${FLEF_DIR}/$(flef-main get project-name "$2")"
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

      echo "$project_path" | tail -c "+$(echo "${FLEF_DIR}" | wc -c)" | cut -d/ -f2
      return 0
      ;;

    *)            return 1 ;;
  esac
}


function flef-find {
  # Runs the find command, inside the flef base directory,
  # filtering for directories directly under it, and print
  # their modified dates and names (separated by a tab)

  find "${FLEF_DIR}" -mindepth 1 -maxdepth 1 -follow \( -type d -o -type l \) $@ -printf '%T@\t%p\n'
  return $?
}


function flef-find-last {
  # Find the last modified flef directory

  local last_offset="${1:-"1"}"

  if [[ ! $last_offset =~ ^[0-9]+$ ]] ; then
    echo "error: command 'flef last [number]' expects number to be a positive integer"
    return 1
  fi

  local recent_project_dir=$(
    flef-find | sort -n | tail -n $last_offset | head -n 1 | cut -f2
  )

  if [[ -z $recent_project_dir ]] ; then
    return 1
  fi

  echo "${recent_project_dir}"
}


function flef-cd {
  local project_dir="${1}"

  if [[ -z $project_dir ]] ; then
    echo "[flef-cd] error: project directory not defined"
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


function flef-rm {
  PROJECT_RM_CONFIRM="${PROJECT_RM_CONFIRM:-1}"

  PROJECT_PATH=$(flef-main get pwd)
  PROJECT_PATH_STATUS=$?

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

  if [ $FLEF_USE_SOURCE ] ; then
    cd "$FLEF_DIR"
  else
    return 0
  fi
}


function flef-link {
  local source_dir="${2:-"$(pwd)"}"
  local project_name="${1:-"$(basename "$source_dir")"}"
  local project_dir="${FLEF_DIR}/$(flef-main get date)_${project_name}"

  ln -s "${source_dir}" "${project_dir}"
  echo "$project_dir"
}


function flef-main {
  # Create the flef directory if it does not exist

  if [[ ! ( -d "${FLEF_DIR}" || -L "${FLEF_DIR}" ) ]] ; then
    mkdir -p "${FLEF_DIR}"
  fi

  case "$1" in
    help) echo "$FLEF_USAGE"                      ; return  1 ;;
    rm)   flef-rm                                 ; return $? ;;
    link) shift ; flef-cd "$(flef-link "$@")"     ; return $? ;;
    sync) shift ; "$FLEF_INSTALLATION/sync.pl" $@ ; return $? ;;
    get)  shift ; flef-get $@                     ; return $? ;;

    last)
      # Find last project directory
      shift

      # do not assign here, in order to capture status:
      #   https://stackoverflow.com/a/50494835
      #
      local last_project_dir
      local last_project_status
      last_project_dir="$(flef-find-last $@)"
      last_project_status=$?

      if [[ $last_project_status -ne 0 ]] ; then
        echo "[flef-find-last] $last_project_dir"
        echo "[flef-main] error: Could not find last project directory"
        return $last_project_status
      fi

      flef-cd "${last_project_dir}"
      return $?
      ;;

    '')
      # Enters the most recently modified flef directory with the current date,
      # and if not found, creates a new one.

      local today_project_dir=$(
        flef-find -name "$(flef-get date)*" | sort -n | tail -n 1 | cut -f2
      )

      if [[ -z "$today_project_dir" ]] ; then
        flef-cd "${FLEF_DIR}/$(flef-get date)"
        return $?
      fi

      flef-cd "${today_project_dir}"
      return $?
      ;;

    *)
      # Use a flef directory with a given name, creating it if needed
      flef-cd "${FLEF_DIR}/$(flef-get date)_${1}"
      ;;
  esac
}

flef-main $@
