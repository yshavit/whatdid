#!/bin/bash

sha="$(git log -n 1 '--pretty=format:%h')"

git_dirty=''
if [[ $(git status -s | wc -c) -ne 0 ]]; then 
  git_dirty='-dirty'
fi

build_string="${sha}${git_dirty}"

target_plist="$TARGET_BUILD_DIR/$INFOPLIST_PATH"
dsym_plist="$DWARF_DSYM_FOLDER_PATH/$DWARF_DSYM_FILE_NAME/Contents/Info.plist"
for plist in "$target_plist" "$dsym_plist"; do
  if [ -f "$plist" ]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $build_string" "$plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $build_string" "$plist"
  fi
done
