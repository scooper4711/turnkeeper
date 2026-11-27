import Foundation
import ImageIO
import UniformTypeIdentifiers

public extension LibraryPackage {
    /// The package with its PNG pictures stored as HEIC, which keeps their transparency at about a sixth of the
    /// size (R1.2b). The records that point to a picture follow it to its new name. A picture that can't be
    /// converted, or wouldn't get smaller, stays as it is.
    func compressingImages() -> LibraryPackage {
        var package = self
        for (fileName, data) in images where fileName.hasSuffix(".png") {
            guard let smaller = Self.heic(fromPNG: data), smaller.count < data.count else { continue }
            let stored = StoredImage(fileName: String(fileName.dropLast(3)) + "heic", byteCount: smaller.count)
            package.images[fileName] = nil
            package.images[stored.fileName] = smaller
            package.library.moveImage(fileName, to: stored)
        }
        return package
    }

    /// The picture as HEIC, or nil where this device can't write HEIC.
    private static func heic(fromPNG data: Data) -> Data? {
        let output = NSMutableData()
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              let destination = CGImageDestinationCreateWithData(output, UTType.heic.identifier as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.8]
                                   as CFDictionary)
        return CGImageDestinationFinalize(destination) ? output as Data : nil
    }
}

extension Library {
    /// Points the art and the handouts kept in one image file at another.
    mutating func moveImage(_ fileName: String, to stored: StoredImage) {
        for index in customArt.indices where customArt[index].fileName == fileName {
            customArt[index].fileName = stored.fileName
            customArt[index].byteCount = stored.byteCount
        }
        for index in handouts.indices where handouts[index].fileName == fileName {
            handouts[index].fileName = stored.fileName
            handouts[index].byteCount = stored.byteCount
        }
    }
}
