#!/bin/bash

buildnum="$(git log -n 1 '--pretty=format:%h')"
if [[ $(git status -s | wc -c) -ne 0 ]]; then 
  # See Version.swift for how we parse this
  buildnum="${buildnum}FFFF"
fi
buildnum="$((16#$buildnum))"

target_plist="$TARGET_BUILD_DIR/$INFOPLIST_PATH"
dsym_plist="$DWARF_DSYM_FOLDER_PATH/$DWARF_DSYM_FILE_NAME/Contents/Info.plist"
for plist in "$target_plist" "$dsym_plist"; do
  if [ -f "$plist" ]; then
    short_string="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$plist")"
    if ! grep -q '^[0-9]\+\.[0-9]\+$' <<< "$short_string" ; then
      self_without_prefix="${0#"$SRCROOT"}"
      echo "Error!!"
      echo "Error!!"
      echo "Error!! .$self_without_prefix:"
      echo "Error!! Version number must have exactly two parts ('xx.yy', not 'xx' or 'xx.yy.zz')"
      echo "Error!! Is: $short_string"
      echo "Error!!"
      echo "Error!!"
      exit 1
    fi
    full_string="${short_string}.$buildnum"
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $full_string" "$plist"
  fi
done
