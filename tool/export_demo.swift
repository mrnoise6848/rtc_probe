// Encode actual integration-test screenshots as an animated GIF (no invented frames).
// swift tool/export_demo.swift OUTPUT.gif INPUT1.png INPUT2.png ...
import Foundation
import ImageIO

let arguments = CommandLine.arguments
 guard arguments.count >= 4 else { fatalError("Provide output GIF and at least two input screenshots") }
let output = URL(fileURLWithPath: arguments[1])
guard let destination = CGImageDestinationCreateWithURL(output as CFURL, "com.compuserve.gif" as CFString, arguments.count - 2, nil) else {
  fatalError("Cannot create GIF")
}
CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
for path in arguments.dropFirst(2) {
  guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
        let frame = CGImageSourceCreateImageAtIndex(source, 0, nil) else { fatalError("Cannot read screenshot: \(path)") }
  CGImageDestinationAddImage(destination, frame, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 2.5]] as CFDictionary)
}
guard CGImageDestinationFinalize(destination) else { fatalError("Cannot finalize GIF") }
