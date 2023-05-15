// whatdid?

import Cocoa

#if UI_TEST
private let SUPPRESS_TUTORIAL_KEY = "SUPPRESS_TUTORIAL"
private let SUPPRESS_TUTORIAL_VAL = "true"
let SHOW_TUTORIAL_ON_FIRST_START = ProcessInfo.processInfo.environment[SUPPRESS_TUTORIAL_KEY] != SUPPRESS_TUTORIAL_VAL
let SILENT_STARTUP = true

func startupEnv(suppressTutorial: Bool) -> [String: String] {
    var env = [String: String]()
    if suppressTutorial {
        env[SUPPRESS_TUTORIAL_KEY] = SUPPRESS_TUTORIAL_VAL
    }
    return env
}

#else
let SHOW_TUTORIAL_ON_FIRST_START = true
let SILENT_STARTUP = false
#endif
