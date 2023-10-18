---
title: Whatdid Privacy Policy
---

# Whatdid privacy policy

## tl;dr:

- All data is anonymized.
- I will _never_ track specific content like your projects, tasks, or notes.
- I will never sell or give away your data.
- You can opt out any time time, including having your data deleted on my server.

## What I collect, and why

_**If you opt out of usage tracking, I won't collect a thing.**_ Not even your decision to opt out of tracking.

I would like to track a small amount of usage data in order to improve the app's UX. For example, I may track how often people edit entries to gauge whether it's a feature people know about.

If you opt into usage:

- All tracking is identified by a random, unique number that your computer generates the first time Whatdid runs. I cannot track this back to any individual or computer.
- I will never, ever, ever sell or give away the data I track.
- I only track "what you used"-style events, like clicking on UI elements. I will never track the content of anything you type.
- You can ask for your data at any time, or ask for it to be deleted. See below for how.
- Although I don't track IP addresses today, I reserve the right to do so if I need to for security reasons (for example, to look into someone attacking my server).
  If I do, any such logs will be short-lived, and I will delete them as soon as my investigation is complete.

In short, none of the data I collect will be sensitive.

## Accessing or deleting your data

To see your data, or request that I delete it, please fill out the [feedback form][feedback]. This is a Google Sheets form, but you don't need to be logged into a Google account to use it.
(Even if you are logged in, the form doesn't record your login or email address). Simply include your request and your tracking UUID as described below. If you are requesting to see your data,
please also include an email address to send it to.

To get your UUID:

1. Open up the Terminal app by opening Spotlight, and searching for Terminal.
2. Type:
   ```
   defaults read com.yuvalshavit.whatdid whatdid.analyticsTrackerId
   ```
   (and then hit enter)

[feedback]: https://docs.google.com/forms/d/e/1FAIpQLSdW4IfggikujQDN_emQU3_TL3aSOUK3At2HPbSYcc6ryHYzzQ/viewform

## Technical Details

You only need to read this section if you want a peek under the hood, at the code itself. This section is meant as a starting point to help you audit the code.

All tracking is done via a UUID your computer randomly generates. You can find this UUID by opening up a Terminal and running the `defaults` command above. You can delete this by replacing
`read` with `delete`, but Whatdid will create a new one the next time it starts up.

Virtually all handling of usage tracking is done by [the `UsageTracking` class][gh:UsageTracking]. (The only other bits are the two `analytics*` vars [in `Prefs`][gh:Prefs].) This class takes in events,
records them to the local Core Data store, and then sends them to the Whatdid server.

The events are defined in [the `UsageTrackingJsonDatum` class][gh:UsageTrackingJsonDatum] — this is the only data I ever send to the server. The event types are defined in [the `UsageAction` enum][gh:UsageAction].

Every recorded event comes in via the `recordAction` call. You can [search the code][gh:search01] to see every place this gets invoked.

[gh:UsageTracking]: https://github.com/yshavit/whatdid/blob/main/whatdid/util/usagetracking/UsageTracking.swift
[gh:Prefs]: https://github.com/yshavit/whatdid/blob/main/whatdid/util/Prefs.swift
[gh:UsageAction]: https://github.com/yshavit/whatdid/blob/main/whatdid/util/usagetracking/UsageAction.swift
[gh:UsageTrackingJsonDatum]: https://github.com/yshavit/whatdid/blob/main/whatdid/util/usagetracking/UsageTrackingJsonDatum.swift
[gh:search01]: https://github.com/search?q=repo%3Ayshavit%2Fwhatdid%20recordAction&type=code

[gh:UsageTracking]: https://github.com/search?q=repo%3Ayshavit%2Fwhatdid+UsageTracking&type=code
