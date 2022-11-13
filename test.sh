#!/usr/bin/env bash

CMDNAME=`basename $0`

while getopts p:d: OPT
do
  case $OPT in
    "p") FLG_P="TRUE" ; VALUE_P="$OPTARG" ;;
    "d") FLG_D="TRUE" ; VALUE_D="$OPTARG" ;;
    \?) echo "no options" ;;
#    * ) echo "Usage: $CMDNAME [-p port_number] [-d dir_name]" 1>&2
#      exit 1 ;;
  esac
done

if [ "$FLG_P" = "TRUE" ]; then
  echo '"-p" option is specified'
  echo "→The value is $VALUE_P"
fi

if [ "$FLG_D" = "TRUE" ]; then
  echo '"-d" option is specified'
  echo "→The value is $VALUE_D"
fi

exit 0
