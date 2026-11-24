import Foundation
import Testing
@testable import TurnkeeperKit

@Suite("The listening meter's frequency bands")
struct SpectrumAnalyzerTests {
    private let analyzer = SpectrumAnalyzer(sampleRate: 48_000)

    private func sine(_ frequency: Double, amplitude: Float = 0.5, count: Int = 1024) -> [Float] {
        (0..<count).map { amplitude * Float(sin(2 * .pi * frequency * Double($0) / 48_000)) }
    }

    private func loudest(_ bands: [Float]) -> Int? {
        bands.indices.max { bands[$0] < bands[$1] }
    }

    @Test("Silence gives all zeros")
    func silence() {
        #expect(analyzer.bands(of: Array(repeating: 0, count: 1024), count: 24) == Array(repeating: 0, count: 24))
    }

    @Test("A sine peaks in its band, higher notes in higher bands")
    func peaks() {
        let low = analyzer.bands(of: sine(440), count: 24)
        let high = analyzer.bands(of: sine(4_000), count: 24)
        #expect(loudest(low) == SpectrumAnalyzer.band(containing: 440, count: 24))
        #expect(loudest(high) == SpectrumAnalyzer.band(containing: 4_000, count: 24))
        #expect((loudest(high) ?? 0) > (loudest(low) ?? 0))
    }

    @Test("There are as many bands as asked, each from 0 to 1")
    func range() {
        let bands = analyzer.bands(of: sine(1_000, amplitude: 1, count: 2000), count: 16)
        #expect(bands.count == 16)
        #expect(bands.allSatisfy { (0...1).contains($0) })
        #expect(bands.max() ?? 0 > 0.9, "a full-scale sine reaches the top")
    }

    @Test("Too few samples, or no bands, give nothing to show")
    func tooFew() {
        #expect(analyzer.bands(of: [0.5, -0.5], count: 4) == [0, 0, 0, 0])
        #expect(analyzer.bands(of: sine(440), count: 0).isEmpty)
    }

    @Test("Frequencies outside the speech range have no band")
    func outside() {
        #expect(SpectrumAnalyzer.band(containing: 40, count: 24) == nil)
        #expect(SpectrumAnalyzer.band(containing: 10_000, count: 24) == nil)
        #expect(SpectrumAnalyzer.band(containing: 80, count: 24) == 0)
    }
}
