import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import TurnkeeperKit

/// A PNG with transparency: detailed when `isDetailed`, so that it is large as PNG, else one flat color.
private func transparentPNG(side: Int, isDetailed: Bool) -> Data {
    var pixels = [UInt8](repeating: 0, count: side * side * 4)
    var seed: UInt32 = 12_345
    for index in pixels.indices {
        seed = seed &* 1_664_525 &+ 1_013_904_223
        pixels[index] = isDetailed ? UInt8(truncatingIfNeeded: seed >> 24) / 2 : 90
    }
    let output = NSMutableData()
    pixels.withUnsafeMutableBytes { buffer in
        guard let context = CGContext(data: buffer.baseAddress, width: side, height: side, bitsPerComponent: 8,
                                      bytesPerRow: side * 4, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let image = context.makeImage(),
              let destination = CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil)
        else { return }
        CGImageDestinationAddImage(destination, image, nil)
        CGImageDestinationFinalize(destination)
    }
    return output as Data
}

/// Whether this machine can write HEIC at all: a runner with nobody logged in may not have the encoder.
private let canWriteHEIC: Bool = {
    var package = LibraryPackage(library: Library(), bestiaryRevision: "")
    package.images["probe.png"] = transparentPNG(side: 128, isDetailed: true)
    return package.compressingImages().images["probe.heic"] != nil
}()

@Suite("Smaller pictures in a file")
struct PackageCompressionTests {
    /// A package with one piece of pasted art and one handout in the same kind of picture, and a JPEG.
    private func package(isDetailed: Bool) -> LibraryPackage {
        let picture = transparentPNG(side: 128, isDetailed: isDetailed)
        var library = Library()
        library.save(CustomArt(subject: "goblin", fileName: "goblin.png", byteCount: picture.count))
        var map = Handout(scenarioID: UUID(), name: "Map")
        map.fileName = "map.png"
        map.byteCount = picture.count
        library.save(map)
        library.save(CustomArt(subject: "wolf", fileName: "wolf.jpg", byteCount: 3))
        var package = LibraryPackage(library: library, bestiaryRevision: "")
        package.images = ["goblin.png": picture, "map.png": picture, "wolf.jpg": Data([1, 2, 3])]
        return package
    }

    @Test("A PNG becomes a smaller HEIC that keeps its transparency, and its records follow it",
          .enabled(if: canWriteHEIC, "Writing HEIC needs an encoder this machine doesn't have"))
    func compresses() throws {
        let original = package(isDetailed: true)
        let compressed = original.compressingImages()
        #expect(compressed.images.keys.sorted() == ["goblin.heic", "map.heic", "wolf.jpg"])
        let picture = try #require(compressed.images["goblin.heic"])
        let before = try #require(original.images["goblin.png"])
        #expect(picture.count < before.count)
        let source = try #require(CGImageSourceCreateWithData(picture as CFData, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(image.width == 128 && ![.none, .noneSkipFirst, .noneSkipLast].contains(image.alphaInfo))
        let art = try #require(compressed.library.customArt(for: "goblin"))
        #expect(art.fileName == "goblin.heic" && art.byteCount == picture.count)
        #expect(art.id == original.library.customArt(for: "goblin")?.id)
        #expect(compressed.library.handouts.map(\.fileName) == ["map.heic"])
        #expect(compressed.library.liveImageFileNames == Set(compressed.images.keys))
    }

    @Test("A picture that wouldn't get smaller, and one that isn't a PNG, stay as they are")
    func leavesTheRest() {
        let original = package(isDetailed: false)
        let compressed = original.compressingImages()
        #expect(compressed.images == original.images)
        #expect(compressed.library == original.library)
    }

    @Test("A PNG that can't be read stays as it is")
    func unreadable() {
        var package = LibraryPackage(library: Library(), bestiaryRevision: "")
        package.images["broken.png"] = Data("not a picture".utf8)
        #expect(package.compressingImages().images.keys.sorted() == ["broken.png"])
    }
}
