// whatdidUITests?

import XCTest

func findDatePickerBoxes(in picker: XCUIElement) -> [(CoordinateInfo, YearMonthDay)] {
    var results = [(CoordinateInfo, YearMonthDay)]()
    let firstCoordinate = CoordinateInfo(normalizedX: 0.1, normalizedY: 0.5, absoluteX: 0.0, absoluteY: 0.0)
    firstCoordinate.click(in: picker)
    var prevYmd = YearMonthDay.parse(from: picker.value as? String)!
    results.append((firstCoordinate, prevYmd))
    
    for dx in stride(from: 0, to: picker.frame.width, by: 5) {
        let coordinate = firstCoordinate.withAbsoluteOffset(dx: dx, dy: 0)
        coordinate.click(in: picker)
        let currYmd = YearMonthDay.parse(from: picker.value as? String)!
        if currYmd == prevYmd {
            continue
        } else if currYmd == prevYmd.withAdditional(days: 1) {
            results.append((coordinate, currYmd))
            prevYmd = currYmd
            if results.count == 3 {
                break // we only need 3!
            }
        } else {
            XCTFail("skipped from \(prevYmd) to \(currYmd)")
        }
    }
    
    return results
}

struct CoordinateInfo: Hashable {
    let normalizedX: CGFloat
    let normalizedY: CGFloat
    let absoluteX: CGFloat
    let absoluteY: CGFloat
    
    func click(in element: XCUIElement, thenDragTo destination: CoordinateInfo? = nil) {
        let firstCoordinate = toXCUICoordinate(in: element)
        if let destination = destination {
            let secondCoordinate = destination.toXCUICoordinate(in: element)
            firstCoordinate.click(forDuration: 0.5, thenDragTo: secondCoordinate)
        } else {
            firstCoordinate.click()
        }
    }
                            
    func toXCUICoordinate(in element: XCUIElement) -> XCUICoordinate {
        return element
            .coordinate(withNormalizedOffset: CGVector(dx: normalizedX, dy: normalizedY))
            .withOffset(CGVector(dx: absoluteX, dy: absoluteY))
    }
    
    func withAbsoluteOffset(dx: CGFloat, dy: CGFloat) -> CoordinateInfo {
        return CoordinateInfo(normalizedX: normalizedX, normalizedY: normalizedY, absoluteX: absoluteX + dx, absoluteY: absoluteY + dy)
    }
}

struct YearMonthDay: Equatable {
    var year: Int
    var month: Int
    var day: Int
    
    var asDashedString: String {
        return "\(year)-\(month)-\(day)"
    }
    
    func withAdditional(years: Int = 0, months: Int = 0, days: Int = 0) -> YearMonthDay {
        return YearMonthDay(year: year + years, month: month + months, day: day + days)
    }
    
    static func parse(from string: String?) -> YearMonthDay? {
        guard let segments = string?.split(separator: "-", maxSplits: 2),
              segments.count == 3,
              let yy = Int(segments[0]),
              let mm = Int(segments[1]),
              let dd = Int(segments[2])
        else {
            return nil
        }
        return YearMonthDay(year: yy, month: mm, day: dd)
    }
}
