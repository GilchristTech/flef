#!/usr/bin/bash -e

FLEF_DIR="${FLEF_DIR:-"$HOME/flef"}"
FLEF_DATEFORMAT="${FLEF_DATEFORMAT:-%y-%m-%d}"


FLEF_USAGE=$(cat <<EOF
Usage: flef [project_name|last [n]|help]
  no arguments     Go to the last project from today, or create a new one
  project_name     Create a project directory with the provided name
                   (e.g., flef my-project)
  last [n]         Move into the last modified flef directory,
                   optionally selecting the Nth most recent directory
  help             Show this usage outline
EOF
)


function flef-usage {
  echo "$FLEF_USAGE"
}


function flef-find {
  # Runs the find command, inside the flef base directory,
  # filtering for directories directly under it, and print
  # their modified dates and names (separated by a tab)

  find "${FLEF_DIR}" -mindepth 1 -maxdepth 1 -type d $@ -printf '%T@\t%p\n'
  return $?
}


function flef-find-last {
  # Find the last modified flef directory

  local last_offset="$1"

  if [ $last_offset  ] ; then
    if [[ ! $last_offset =~ ^[0-9]+$ ]] ; then
      echo "error: command 'flef last [number]' expects number to be a positive integer"
      return 1
    fi
  else
    last_offset=1
  fi

  local recent_project_dir=$(
      flef-find | sort -n | tail -n $last_offset | head -n 1 | cut -f2
  )

  if [[ ! $recent_project_dir ]] ; then
      echo "No last modified flef directory"
      return 1
  fi

  echo "${recent_project_dir}"
}


function flef-get-project-name {
  # Given a path at $1, return the name of the project,
  # based off the intersection of that path and $FLEF_DIR.
  # This function does not process symbolic links.

  if [[ ! $1 = "$FLEF_DIR"/* ]] ; then
    >&2 echo "error: Directory is not a flef project directory"
    return 1
  fi

  echo "$1" | tail -c "+$(echo "${FLEF_DIR}" | wc -c)" | cut -d/ -f2
  return 0
}


function flef-get-project-path {
  # Given the directory at $1, print the root of the flef project directory

  if [[ ! "$1" = "$FLEF_DIR"/* ]] ; then
    >&2 echo "error: Directory is not a flef project directory"
    return 1
  fi

  echo "${FLEF_DIR}/$(flef-get-project-name "$1")"
}


function flef-cd {
  local project_dir="${1}"

  # If the project directory doesn't exist, create it

  if [[ ! ( -d "$project_dir" || -L "$project_dir") ]] ; then
    mkdir "$project_dir"
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

  PROJECT_PATH=$(flef-get-project-path "${PWD}")
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


function flef-main () {
  # Create the flef directory if it does not exist

  if [[ ! ( -d "${FLEF_DIR}" ) ]] ; then
    mkdir "${FLEF_DIR}"
  fi

  local date="$(date +"${FLEF_DATEFORMAT}")"
  local project_dir="${FLEF_DIR}/$date"

  if [[ "$1" == 'help' ]]; then
    flef-usage
    return $?

  elif [[ "$1" == 'last' ]] ; then
    shift
    flef-cd "$(flef-find-last $@)"
    return $?

  elif [[ "$1" == 'rm' ]] ; then
    flef-rm
    return $?

  elif [[ $1 ]] ; then
    # Use a flef directory with a given name, creating it if needed
    flef-cd "${project_dir}_${1}"

  else
    # Find the most recently modified flef directory with the current date

    local recent_project_dir=$(
      flef-find -name "${date}*" | sort -n | tail -n 1 | cut -f2
    )

    flef-cd "${project_dir}"
    return $?
  fi
}

flef-main $@
