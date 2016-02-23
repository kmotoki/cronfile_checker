#!/bin/bash
function show_usage() {
  echo "usage: $0 HOSTNAME"
  echo ""
  echo "Check file format below:"
  echo "  /etc/crontab"
  echo "  /etc/cron.d/*"
}

function check_file_format() {
  local result=(`ssh $1 export LANG=en_US\; stat -c \'%n %U:%G %a %h %F\' $2`)
  if [ ${#result[@]} -eq 0 ]; then
    exit 1
  fi

  local error_message=""

  # Check owner.
  if [ ${result[1]} != "root:root" ]; then
    error_message="\tInvalid owner: ${result[1]}\n"
  fi

  # Check permission.
  group=`echo ${result[2]} | cut -c 2`
  other=`echo ${result[2]} | cut -c 3`
  if [ $(($group % 4)) -ne 0 ] || [ $(($other % 4)) -ne 0 ]; then
    error_message=$error_message"\tNo cron files may be executable, or be writable by any user other than their owner: ${result[2]}\n"
  fi

  # Check whether the file is linked.
  if [ ${result[3]} -gt 1 ]; then
    error_message=$error_message"\tNo cronfile may be linked by any other file.\n"
  fi

  # Check whether the file is link.
  if [ ${#result[@]} -ne 6 ] || [ "${result[4]} ${result[5]}" != "regular file" ]; then
    error_message=$error_message"\tNo cron files may be links.\n"
  fi

  # Check whether the file is end with LF or comment-line.
  if [ `ssh $1 tail -1 $2 | wc -l` -ne 1 ]; then
    if [ -z "`ssh $1 tail -1 $2 | grep \"^\s*#\"`" ]; then
      error_message=$error_message"\tEach line mast be end with LF or \"%\" character.\n"
    fi
  fi

  if [ -n "$error_message" ]; then
    echo $2
    echo -e $error_message
  fi
}

if [ $# -ne 1 ]; then
  show_usage
  exit 1
fi

if [ $1 = "-h" ] || [ $1 = "--help" ]; then
  show_usage
  exit 0
fi

check_file_format $1 "/etc/crontab"

cronfiles=(`ssh $1 find /etc/cron.d/ -mindepth 1 -maxdepth 1`)
for cronfile in ${cronfiles[@]}; do
  check_file_format $1 $cronfile
done

