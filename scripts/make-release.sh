#!/bin/bash

# Script to simplify the release/hotfix flow
# 1) Fetch the current release tag version and validate. Following semantic versioning rule. For example: 1.0.1
# 2) Increase the version (major, minor, patch)
# 3.1) If is_hotfix is true, then Checkout master branch if current branch is not master branch
# 3.2) If is_hotfix is true, then create a hotfix branch
# 4.1) If is_hotfix is not true, then checkout develop branch if current branch is not develop
# 4.2) Create a new release branch off develop branch
# 4.3) Run command for merging origin/master to release branch

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
  echo " Example: sh scripts/make-release.sh -p"
  echo " means create a patch release"
  exit 1
fi

# 1) Fetch the current release version and validate

echo "Fetch tags"
git fetch --prune --tags

version=$(git describe --tags $(git rev-list --tags --max-count=1))

# First time release
if [ -z "$version" ]
then
     version=0.0.0
fi

# Validate current version
rx='^([0-9]+\.){0,2}(\*|[0-9]+)$'
if [[ $version =~ $rx ]]; then
 echo "Current version: $version"
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

echo "Next version: $next_version"

# current Git branch
branch=$(git symbolic-ref HEAD | sed -e 's,.*/\(.*\),\1,')
echo "Current branch: $branch"

if [ ! -z $is_hotfix ] # Create a hotfix branch
then
  # If a command fails, exit the script
  set -e

  if [[ $branch != "main" ]]
  then
    git checkout main
    git pull
    echo "Checkout main branch."
  fi

  # establish branch variable
  hotfixBranch=hotfix/$next_version

  # create the hotfix branch from the -master branch
  git checkout -b $hotfixBranch
  echo "$hotfixBranch branch created."

  git commit -m "$hotfixBranch branch created."
  git push $hotfixBranch

else # Create a release branch
  # If a command fails, exit the script
  set -e

  # if current branch is not develop branch
  if [[ $branch != "develop" ]]
  then
    git checkout develop
    git pull
    echo "Checkout develop branch."
  fi

  # establish branch variable
  releaseBranch=release/$next_version

  # create the release branch from the -develop branch
  git checkout -b $releaseBranch
  echo "$releaseBranch branch created."
  
  git commit -m "$releaseBranch branch created."
  git push $releaseBranch
fi