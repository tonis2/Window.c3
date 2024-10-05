import Cocoa
import Foundation

@objc public class Params: NSObject {
    var depth: CInt = 0
    var x: CInt = 0
    var y: CInt = 0
    var width: CInt = 0
    var height: CInt = 0
    var border_width: CInt = 0
}

@_cdecl("createWindow")
public func createWindow(params: Params) -> CInt {
    let value: CInt = 69
    return value;
}