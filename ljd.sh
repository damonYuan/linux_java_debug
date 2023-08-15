#!/bin/bash
# ---------------------------------------------------------------------------
# ljd - Linux & Java Debugger
# ---------------------------------------------------------------------------

PROGNAME=${0##*/}
VERSION="0.1"
DRY_RUN=false

clean_up() { # Perform pre-exit housekeeping
  unset p
  DRY_RUN=false
  return
}

error_exit() {
  echo -e "${PROGNAME}: ${1:-"Unknown Error"}" >&2
  clean_up
  exit 1
}

graceful_exit() {
  clean_up
  exit
}

signal_exit() { # Handle trapped signals
  case $1 in
    INT)
      error_exit "Program interrupted by user" ;;
    TERM)
      echo -e "\n$PROGNAME: Program terminated" >&2
      graceful_exit ;;
    *)
      error_exit "$PROGNAME: Terminating on unknown signal" ;;
  esac
}

usage() {
  echo -e "Usage: $PROGNAME [-h|--help] [-dry|--dry_run] [-o|--open_files p] [-l|--large_disk_usage p] [-d|--delete p r k]"
}

help_message() {
  cat <<- _EOF_
  $PROGNAME ver. $VERSION
  disk utils for CQ

  $(usage)

  Options:
  -h, --help  Display this help message and exit.
  -dry, --dry_run  Dry run for tests the following command.
  -o, --open_files  List open files.
    Where 'p' is the path.
  -l, --large_disk_usage  Check large disk usage.
    Where 'p' is the path, default "/data/cq".

_EOF_
  return
}

# Trap signals
trap "signal_exit TERM" TERM HUP
trap "signal_exit INT"  INT

get_open_cq_files() {
  echo "checking open files in ${p}"
  lsof | grep -E "${p}" | grep -v grep | uniq
}

large_disk_usage() {
  echo "checking large disk usage in ${p}"
  cd ${p} || exit
  du -h | grep G
}

trace() {
  echo "tracing the process id: ${p}"
  strace -p ${p} -f -e trace=network,open,close,write -s 10000
}

java_thread_dump() {
  echo "thread dump process id: ${p} to ${f}"
  jstack ${p} > ${f}
}

java_heap_dump() {
  echo "heap dump process id: ${p} to ${f}"
  jmap -dump:[live],format=b,file=${f} ${p}
}

process_of_a_port() {
  echo "process id of port: ${p}"
  netstat -ltnp | grep -w ":${p}"
  # lsof -i :${p}
}

# Parse command-line
while [[ -n $1 ]]; do
  [[ ${DRY_RUN} = true ]] && echo "dry run";
  case $1 in
    -h | --help)
      help_message; graceful_exit ;;
    -o | --open_files)
      echo "list opening CQ files";
      if [[ $# -eq 2 ]]; then
        shift; p="$1";
      fi
      get_open_cq_files ;;
    -l | --large_disk_usage)
      echo "check large disk usage";
      if [[ $# -eq 2 ]]; then
        shift; p="$1";
      fi
      large_disk_usage ;;
    -dry | --dry_run)
      DRY_RUN=true;;
    -* | --*)
      usage
      error_exit "Unknown option $1" ;;
    *)
      echo "Argument $1 to process..." ;;
  esac
  shift
done

graceful_exit

