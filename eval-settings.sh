# This file is meant to be a polyglot which runs in your terminal
# of choice, so long as it has bash-compatible syntax. By running
# it in a shell, as long as your runtime commands have executed,
# it should print Flef-related environment variables, prefixed
# with __FLEF_SETTING__. These lines are meant to be
# easily-filtered so that if the terminal with runtime commands
# prints anything else, settings values can still be retrieved.
#
# For this to work, the shell must support 

FLEF_INSTALLATION="${FLEF_INSTALLATION:-''}"
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

FLEF_DIR=${FLEF_DIR:-"${HOME}/flef"}
FLEF_USE_SOURCE=${FLEF_USE_SOURCE:-''}
FLEF_DATEFORMAT=${FLEF_DATEFORMAT:-'%y-%m-%d'}

echo "__FLEF_SETTING__\tFLEF_INSTALLATION\t${FLEF_INSTALLATION}"
echo "__FLEF_SETTING__\tFLEF_DIR\t${FLEF_DIR}"
echo "__FLEF_SETTING__\tFLEF_USE_SOURCE\t${FLEF_USE_SOURCE}"
echo "__FLEF_SETTING__\tFLEF_DATEFORMAT\t${FLEF_DATEFORMAT}"
