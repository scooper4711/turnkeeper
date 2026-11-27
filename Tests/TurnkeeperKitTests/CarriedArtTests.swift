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
        #expect(package.keepingImages(phone.liveImageFileNames).images.isEmpty, "its picture isn't written again")
    }

    @Test("Imported art replaces the pasted art a creature had, as pasting does, and leaves other creatures alone")
    func replacesLikeAPaste() throws {
        let (package, art) = try arrivingPackage(for: "goblin")
        var phone = Library()
        phone.save(CustomArt(subject: "goblin", fileName: "own.jpg", byteCount: 1))
        phone.save(CustomArt(subject: "wolf", fileName: "wolf.jpg", byteCount: 1))
        _ = LibraryMerger.merge(package.library, into: &phone)
        phone.replaceArt(withThatOf: package.library)
        #expect(phone.customArt(for: "goblin")?.id == art.id)
        #expect(phone.liveArtFileNames == [art.fileName, "wolf.jpg"])
    }

    @Test("When the organizer changes a creature's art and sends again, the old picture goes")
    func changedArtLeavesNothingBehind() throws {
        let (first, old) = try arrivingPackage(for: "goblin")
        let (second, new) = try arrivingPackage(for: "goblin")
        var phone = Library()
        for package in [first, second, second] {
            _ = LibraryMerger.merge(package.library, into: &phone)
            phone.replaceArt(withThatOf: package.library)
        }
        #expect(phone.liveArtFileNames == [new.fileName] && old.id != new.id)
        #expect(phone.customArt.filter { !$0.isDeleted }.count == 1)
    }

    /// A file's name is no part of what it holds, so "Convention.turnkeeper" and "Convention (2).turnkeeper" differ
    /// only in when they were exported.
    @Test("The same art exported twice, at different times, arrives as one picture")
    func sameArtInTwoFiles() throws {
        let image = try picture()
        let source = UUID()
        var phone = Library()
        for exportedAt in [Date(timeIntervalSince1970: 1_000), Date(timeIntervalSince1970: 2_000)] {
            var package = LibraryPackage(library: Library(), bestiaryRevision: "", exportedAt: exportedAt)
            package.add(CustomArt.carried(source, for: "goblin", image: image), image: image.data)
            let arrived = try LibraryPackage.decode(package.encoded())
            _ = LibraryMerger.merge(arrived.library, into: &phone)
            phone.replaceArt(withThatOf: arrived.library)
            #expect(Set(arrived.images.keys) == phone.liveArtFileNames)
        }
        #expect(phone.customArt.count == 1)
    }

    @Test("Art pasted after an import survives importing the same file again")
    func ownArtPastedLaterStays() throws {
        let (package, _) = try arrivingPackage(for: "goblin")
        var phone = Library()
        _ = LibraryMerger.merge(package.library, into: &phone)
        phone.replaceArt(withThatOf: package.library)
        phone.save(CustomArt(subject: "goblin", fileName: "own.jpg", byteCount: 1))
        _ = LibraryMerger.merge(package.library, into: &phone)
        phone.replaceArt(withThatOf: package.library)
        #expect(phone.liveArtFileNames == ["own.jpg"])
    }
}
