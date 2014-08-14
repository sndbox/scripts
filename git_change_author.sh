#!/bin/sh

OLD_NAME=""
NEW_EMAIL=""
NEW_NAME=""

git filter-branch --commit-filter '
  if [ "$GIT_COMMITTER_NAME" = "$OLD_NAME" ]; then
    GIT_COMMITTER_NAME="$NEW_NAME";
    GIT_AUTHOR_NAME="$NEW_NAME";
    GIT_COMMITTER_EMAIL="$NEW_EMAIL";
    GIT_AUTHOR_EMAIL="$NEW_EMAIL";
    git commit-tree "$@";
  fi' HEAD
