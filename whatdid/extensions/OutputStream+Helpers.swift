// whatdid?

import Cocoa


let newlineUtfData = "\n".data(using: .utf8)!

extension OutputStream {
    // taken from https://stackoverflow.com/a/26992040/1076640
    
    enum OutputStreamError: Error {
        case stringConversionFailure
        case bufferFailure
        case writeFailure
    }
    
    func write(_ string: String) throws {
        guard let data = string.data(using: .utf8) else {
            throw OutputStreamError.stringConversionFailure
        }
        try write(data)
    }
    
    func write(_ data: Data) throws {
        try data.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) in
            guard var pointer = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                throw OutputStreamError.bufferFailure
            }

            var bytesRemaining = buffer.count

            while bytesRemaining > 0 {
                let bytesWritten = write(pointer, maxLength: bytesRemaining)
                if bytesWritten < 0 {
                    throw OutputStreamError.writeFailure
                }

                bytesRemaining -= bytesWritten
                pointer += bytesWritten
            }
        }
    }
}
