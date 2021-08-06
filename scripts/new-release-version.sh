#!/bin/bash

# Script to simplify the release/hotfix flow
# 1) Fetch the current release tag version and validate. Following semantic versioning rule. For example: 1.0.1
# 2) Increase the version (major, minor, patch)
# 3) Establish new branch variables

# Parse command line options.
while getopts ":Mmph" Option
do
  case $Option in
    M ) major=true;;
    m ) minor=true;;
    p ) patch=true;;
    h ) is_hotfix=true
        patch=true;;
  esac
done

shift $(($OPTIND - 1))

# Display usage
if [ -z $major ] && [ -z $minor ] && [ -z $patch ]
then
  echo "usage: $(basename $0) [Mmph] [message]"
  echo ""
  echo "  -M for a major release"
  echo "  -m for a minor release"
  echo "  -p for a patch release"
  echo "  -h for a patch hotfix"
  echo ""
  echo " Example: sh scripts/new-release-version.sh -p"
  echo " means create a patch release or hotfix"
  exit 1
fi

# establish branch variables
devBranch=develop
masterBranch=master

# 1) Fetch the current release version and validate
git fetch --prune --tags

version=$(git describe --tags $(git rev-list --tags --max-count=1))

# First time release
if [ -z "$version" ]
then
     version=0.0.0
fi

# Validate current version
rx='^([0-9]+\.){0,2}(\*|[0-9]+)$'
if [[  $version =~ $rx ]]; then
 true
else
 echo "ERROR:<->invalidated version: '$version'"
 exit 1
fi

# 2) Increase version number

# Build array from version string.

a=( ${version//./ } )

# Increment version numbers as requested.

if [ ! -z $major ]
then
  ((a[0]++))
  a[1]=0
  a[2]=0
fi

if [ ! -z $minor ]
then
  ((a[1]++))
  a[2]=0
fi

if [ ! -z $patch ]
then
  ((a[2]++))
fi

next_version="${a[0]}.${a[1]}.${a[2]}"

# current Git branch
branch=$(git symbolic-ref HEAD | sed -e 's,.*/\(.*\),\1,')

if [ ! -z $is_hotfix ] # new hotfix branch name
then
  # If a command fails, exit the script
  set -e

  # establish branch variable
  echo hotfixBranch=hotfix/$next_version

else # new release branch name
  # If a command fails, exit the script
  set -e

  # establish branch variable
  echo releaseBranch=release/$next_version
fi
