#!/bin/bash -e

sha="$(git log -n 1 '--pretty=format:%h')"
if [[ $(git status -s | wc -c) -ne 0 ]]; then 
  sha="${sha}.dirty"
fi

info_plist="$BUILT_PRODUCTS_DIR/$INFOPLIST_PATH"
target_plist="$TARGET_BUILD_DIR/$INFOPLIST_PATH"
dsym_plist="$DWARF_DSYM_FOLDER_PATH/$DWARF_DSYM_FILE_NAME/Contents/Info.plist"
for plist in "$info_plist" "$target_plist" "$dsym_plist"; do
  if [ -f "$plist" ]; then
    echo "Found plist:  $plist"
    old_sha=$(/usr/libexec/PlistBuddy -c "Print :ComYuvalShavitWtfdidVersion" "$plist" || echo '<none>')
    if [[ "$old_sha" != "$sha" ]] ; then
      echo "Updating sha to $sha (was: $old_sha)"
      /usr/libexec/PlistBuddy -c "Delete :ComYuvalShavitWtfdidVersion" "$plist" || true
      /usr/libexec/PlistBuddy -c "Add :ComYuvalShavitWtfdidVersion string $sha" "$plist"
    else
      echo "Found old sha ($sha), leaving untouched."
    fi
  else
    echo "Missing plist: $plist"
  fi
done
