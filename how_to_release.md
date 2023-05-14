1. Publish a new release on GH.
    1. Create a new tag
    2. Mark the release as pre-release to flag this as an alpha release.
       (This affects whether all users will get it, or only those who have
       opted into alphas.)
2. Wait for the "on release" GH action to run. It'll be named after the
   release name from the previous step.
3. That GH action will create a PR. Check that:
    1. ~The symlink at `Whatdid.dmg` has been updated~ (disabling this for now, because I'm not building notarized apps anymore, because I don't want to pay Apple)
    2. The screenshots look good
    3. There's a new release notes `.md` file for this release.
    4. Some `.delta` files got generated
4. Merge the PR and wait for GH actions to update
   https://whatdid.yuvalshavit.com.
