import Foundation

func generateRandomBytesArray(_ length: Int = 32) -> [UInt8] {
    var array: [UInt8] = []
    
    var i = 0
    while i < length {
        array.append(UInt8.random(in: 0...255))
        i += 1
    }
    
    return array
}
