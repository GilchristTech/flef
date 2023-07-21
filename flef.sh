#!/usr/bin/bash -e

function flef-usage () {
  echo "Usage: flef [project_name|last [n]|help]"
  echo "  no arguments    Go to the last project from today, or create a new one"
  echo "  project_name    Create a project directory with the provided name"
  echo "                  (e.g., flef my-project)"
  echo "  last [n]        Move into the last modified flef directory,"
  echo "                  optionally selecting the Nth most recent directorie"
  echo "  help            Show this usage outline"
}


function flef-find () {
  # Runs the find command, inside the flef base directory,
  # filtering for directories directly under it, and print
  # their modified dates and names (separated by a tab)

  find "${FLEF_DIR}" -mindepth 1 -maxdepth 1 -type d $@ -printf '%T@\t%p\n'
  return $?
}


function flef-get-project-name () {
  # Given a path at $1, return the name of the project,
  # based off the intersection of that path and $FLEF_DIR.
  # This function does not process symbolic links.

  if [[ ! $1 = $FLEF_DIR/* ]] ; then
    >&2 echo "error: Directory is not a flef project directory"
    return 1
  fi

  echo "$1" | tail -c "+$(echo "${FLEF_DIR}" | wc -c)" | cut -d/ -f2
  return 0
}


function flef-get-project-path () {
  if [[ ! $1 = $FLEF_DIR/* ]] ; then
    >&2 echo "error: Directory is not a flef project directory"
    return 1
  fi

  echo "${FLEF_DIR}/$(flef-get-project-name "$1")"
}


function flef-rm () {
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
  FLEF_DIR="${FLEF_DIR:-"$HOME/flef"}"
  FLEF_DATEFORMAT="${FLEF_DATEFORMAT:-%y-%m-%d}"

  # Create ~/flef/ if it does not exist

  if [[ ! ( -d "${FLEF_DIR}" ) ]] ; then
    mkdir "${FLEF_DIR}"
  fi

  DATE="$(date +"${FLEF_DATEFORMAT}")"
  PROJECT_DIR="${FLEF_DIR}/$DATE"

  if [[ $1 == 'help' ]]; then
    flef-usage
    return 0

  elif [[ $1 == 'last' ]] ; then
    # Find the last modified flef directory

    LAST_OFFSET=$2

    if [ $LAST_OFFSET  ] ; then
      if [[ ! $LAST_OFFSET =~ ^[0-9]+$ ]] ; then
        echo "error: command 'flef last [number]' expects number to be a positive integer"
        return 1
      fi
    else
      LAST_OFFSET=1
    fi

    RECENT_PROJECT_DIR=$(
        flef-find | sort -n | tail -n $LAST_OFFSET | head -n 1 | cut -f2
    )

    if [[ $RECENT_PROJECT_DIR ]] ; then
        PROJECT_DIR="${RECENT_PROJECT_DIR}"
    else
        echo "No last modified flef directory"
        return 1
    fi

  elif [[ $1 == 'rm' ]] ; then
    flef-rm
    return $?

  elif [[ $1 ]] ; then
    # Use a flef directory with a given name, creating it if needed

    PROJECT_DIR="${PROJECT_DIR}_${1}"

  else
    # Find the most recently modified flef directory with the current date

    RECENT_PROJECT_DIR=$(
        flef-find -name "$DATE*" | sort -n | tail -n 1 | cut -f2
    )

    if [[ "$RECENT_PROJECT_DIR" ]] ; then
        PROJECT_DIR="${RECENT_PROJECT_DIR}"
    fi
  fi

  # If the project directory doesn't exist, create it

  if [[ ! ( -d "$PROJECT_DIR" || -L "$PROJECT_DIR") ]] ; then
    mkdir "$PROJECT_DIR"
  fi

  if [ ! $FLEF_USE_SOURCE ] ; then
    echo "Starting a new shell"
  fi

  echo $PROJECT_DIR
  cd "$PROJECT_DIR"

  # Look for Python virtual environments

  if [ $FLEF_USE_SOURCE ] ; then
    # If this script is being sourced, directly source the virtual environment, if it exists

    if [[ -d "./venv" ]] ; then 
      source ./venv/bin/activate
    fi

    if [[ -d "./env"  ]] ; then 
      source ./env/bin/activate
    fi
  else
    # Detect Python virtualenv directories, and inject them into the shell

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

flef-main $@
