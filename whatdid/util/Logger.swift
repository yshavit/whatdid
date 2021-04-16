// whatdid?

import Cocoa
import os

#if UI_TEST
var globalLogHook = LogHook(add: {_, _ in}, reset: {})

private func logToHook(_ type: OSLogType, _ message: String) {
    if Thread.current.isMainThread {
        globalLogHook.add(type, message)
    } else {
        DispatchQueue.main.async {
            globalLogHook.add(type, message)
        }
    }
}

struct LogHook {
    let add: (OSLogType, String) -> ()
    let reset: Action
}
#endif

// Note: we need all these dumb overloads because you can't pass an array into a vararg in Swift.
// (or rather you can, but it comes through as a single element in the vararg).

func wdlog(_ type: OSLogType, _ message: StaticString) {
    os_log(type, message)
    #if UI_TEST
    logToHook(type, s(message))
    #endif
}

func wdlog(_ type: OSLogType, _ message: StaticString, _ arg0: CVarArg) {
    os_log(type, message, arg0)
    #if UI_TEST
    logToHook(type, String(format: s(message), arg0))
    #endif
}

func wdlog(_ type: OSLogType, _ message: StaticString, _ arg0: CVarArg, _ arg1: CVarArg) {
    os_log(type, message, arg0, arg1)
    #if UI_TEST
    logToHook(type, String(format: s(message), arg0, arg1))
    #endif
}

func wdlog(_ type: OSLogType, _ message: StaticString, _ arg0: CVarArg, _ arg1: CVarArg, _ arg2: CVarArg) {
    os_log(type, message, arg0, arg1, arg2)
    #if UI_TEST
    logToHook(type, String(format: s(message), arg0, arg1, arg2))
    #endif
}

private func s(_ source: StaticString) -> String {
    return source.withUTF8Buffer { String(decoding: $0, as: UTF8.self) }
}
