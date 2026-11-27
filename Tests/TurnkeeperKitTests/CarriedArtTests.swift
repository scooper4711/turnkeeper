import CoreGraphics
import Foundation
import SharedLibraries
import Testing
@testable import TurnkeeperKit

/// Art the sending device draws from the GM's PDFs, sent in a file as the creatures' pasted art (R1.2b).
@Suite("Art carried in a file")
struct CarriedArtTests {
    /// A small drawn picture, as the art library hands one over.
    private func picture(opaque: Bool = true) throws -> PreparedImage {
        let alpha: CGImageAlphaInfo = opaque ? .noneSkipLast : .premultipliedLast
        let context = try #require(CGContext(data: nil, width: 8, height: 6, bitsPerComponent: 8, bytesPerRow: 0,
                                             space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: alpha.rawValue))
        context.setFillColor(CGColor(red: 0.2, green: 0.5, blue: 0.2, alpha: opaque ? 1 : 0.5))
        context.fill(CGRect(x: 0, y: 0, width: 8, height: 6))
        return try PreparedImage(picture: try #require(context.makeImage()))
    }

    /// A package holding one creature's carried art, as it arrives on another device.
    private func arrivingPackage(for subject: String) throws -> (LibraryPackage, CustomArt) {
        let image = try picture()
        let art = CustomArt.carried(UUID(), for: subject, image: image)
        var package = LibraryPackage(library: Library(), bestiaryRevision: "")
        package.add(art, image: image.data)
        return (try LibraryPackage.decode(package.encoded()), art)
    }

    @Test("A drawn picture is kept at its size, as JPEG unless it has transparency")
    func preparingAPicture() throws {
        let opaque = try picture()
        #expect(opaque.fileExtension == "jpg" && opaque.pixelSize == CGSize(width: 8, height: 6))
        #expect(try picture(opaque: false).fileExtension == "png")
    }

    @Test("The same art for the same creature makes the same record every time")
    func sameRecord() throws {
        let source = UUID()
        let image = try picture()
        let art = CustomArt.carried(source, for: "goblin", image: image)
        #expect(art == CustomArt.carried(source, for: "goblin", image: image))
        #expect(art.id != CustomArt.carried(source, for: "wolf", image: image).id)
        #expect(art.id != CustomArt.carried(UUID(), for: "goblin", image: image).id)
        #expect(art.fileName == "\(art.id.uuidString).jpg" && art.byteCount == image.data.count)
        #expect(art.modifiedAt == CustomArt.carriedDate && art.subjectLabel == nil)
    }

    @Test("Carried art can say which creature it shows")
    func labeled() throws {
        let art = CustomArt.carried(UUID(), for: "goblin", image: try picture())
        let label = ArtSubjectLabel(name: "Goblin Warrior", size: .small)
        #expect(art.labeled(label).subjectLabel == label && art.labeled(label).id == art.id)
    }

    @Test("The creatures to carry art for are those in the encounters with no pasted art")
    func keysWithoutPastedArt() {
        var library = Library()
        var encounter = Encounter(scenarioID: UUID(), name: "Docks")
        var variant = encounter.variant("Base")
        variant.slots = ["wolf", "goblin", "dragon", "goblin"].map(EncounterSlot.init(creatureKey:))
        encounter.setVariant(variant)
        library.save(encounter)
        library.save(CustomArt(subject: "wolf", fileName: "wolf.jpg", byteCount: 1))
        library.save(CustomArt(subject: "dragon", fileName: "dragon.jpg", byteCount: 1))
        library.deleteCustomArt(for: "dragon")
        #expect(library.creatureKeysWithoutPastedArt == ["dragon", "goblin"])
    }

    @Test("Carried art arrives with its image as the creature's pasted art, and only once")
    func arrives() throws {
        let (package, art) = try arrivingPackage(for: "goblin")
        let store = ArtStore(directory: FileManager.default.temporaryDirectory
            .appendingPathComponent("TurnkeeperCarriedArtTests-\(UUID().uuidString)", isDirectory: true))
        defer { try? FileManager.default.removeItem(at: store.directory) }
        try package.writeImages(to: store)
        #expect(store.contains(art.fileName))

        var phone = Library()
        #expect(LibraryMerger.merge(package.library, into: &phone).added == 1)
        #expect(phone.customArt(for: "goblin")?.fileName == art.fileName)
        #expect(!LibraryMerger.merge(package.library, into: &phone).changedAnything)
        #expect(phone.customArt.count == 1)
    }

    @Test("Carried art removed on the receiving device stays removed when the file is imported again")
    func staysRemoved() throws {
        let (package, _) = try arrivingPackage(for: "goblin")
        var phone = Library()
        _ = LibraryMerger.merge(package.library, into: &phone)
        phone.deleteCustomArt(for: "goblin")
        #expect(!LibraryMerger.merge(package.library, into: &phone).changedAnything)
        #expect(phone.customArt(for: "goblin") == nil)
    }

    @Test("Art pasted on the receiving device wins over carried art")
    func pastedArtWins() throws {
        let (package, _) = try arrivingPackage(for: "goblin")
        var phone = Library()
        phone.save(CustomArt(subject: "goblin", fileName: "own.jpg", byteCount: 1))
        _ = LibraryMerger.merge(package.library, into: &phone)
        #expect(phone.customArt(for: "goblin")?.fileName == "own.jpg")
    }
}
