#!/bin/bash

#while getopts ":m:" opt; do
#  case $opt in
#    m)
#      major=major
#      para=$OPTARG
#      echo "-a was triggered $major, $para Parameter: $OPTARG"
#      ;;
#    \?)
#      echo "Invalid option: -$OPTARG" >&2
#      exit 1
#      ;;
#    :)
#      echo "Option -$OPTARG requires an argument." >&2
#      exit 1
#      ;;
#  esac
#done

while getopts ":m::p:" Option; do
  case $Option in
    M ) major=true;;
    m )
      minor=true
      para=$OPTARG
      echo "flag: $minor username $OPTARG";;
    p )
      patch=true
      para=$OPTARG
      echo "flag: $patch username $OPTARG";;
    h ) is_hotfix=true
        patch=true;;
  esac
done