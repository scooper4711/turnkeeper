import Accelerate
import Foundation

/// Turns a slice of microphone samples into the bars of a frequency display: a Hann window, a real FFT, and the
/// bins grouped logarithmically from 80 Hz to 8 kHz, where speech is. Each band is 0 (−60 dB or quieter) to 1
/// (a full-scale sine).
public struct SpectrumAnalyzer: Sendable {
    public static let lowestFrequency = 80.0
    public static let highestFrequency = 8_000.0
    /// The quietest level shown, in dB below full scale.
    public static let floor: Float = -60

    public let sampleRate: Double

    public init(sampleRate: Double) {
        self.sampleRate = sampleRate
    }

    /// `count` levels from 0 to 1, low frequencies first. All zeros for silence or too few samples.
    public func bands(of samples: [Float], count: Int) -> [Float] {
        let size = Self.fftSize(for: samples.count)
        guard count > 0, size > 0 else { return Array(repeating: 0, count: max(count, 0)) }
        let power = powerSpectrum(of: Array(samples.suffix(size)))
        let binWidth = sampleRate / Double(size)
        return (0..<count).map { band in
            let (low, high) = Self.edges(of: band, count: count)
            let first = min(Int(low / binWidth), power.count - 1)
            let last = min(max(Int((high / binWidth).rounded(.up)), first + 1), power.count)
            return level(power: power[first..<last].max() ?? 0, size: size)
        }
    }

    /// The band a frequency falls in, or nil outside 80 Hz–8 kHz.
    public static func band(containing frequency: Double, count: Int) -> Int? {
        guard frequency >= lowestFrequency, frequency < highestFrequency else { return nil }
        let position = log(frequency / lowestFrequency) / log(highestFrequency / lowestFrequency)
        return min(Int(position * Double(count)), count - 1)
    }

    /// The lowest and highest frequency of a band, spaced evenly on a log scale.
    static func edges(of band: Int, count: Int) -> (Double, Double) {
        let ratio = highestFrequency / lowestFrequency
        let low = lowestFrequency * pow(ratio, Double(band) / Double(count))
        let high = lowestFrequency * pow(ratio, Double(band + 1) / Double(count))
        return (low, high)
    }

    /// The largest power of two that fits the samples, at least 64; 0 when there are fewer.
    private static func fftSize(for sampleCount: Int) -> Int {
        guard sampleCount >= 64 else { return 0 }
        return 1 << (Int.bitWidth - 1 - sampleCount.leadingZeroBitCount)
    }

    /// The squared magnitude of each bin below the Nyquist frequency.
    private func powerSpectrum(of samples: [Float]) -> [Float] {
        let size = samples.count
        let half = size / 2
        let log2n = vDSP_Length(size.trailingZeroBitCount)
        guard let setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else { return [] }
        defer { vDSP_destroy_fftsetup(setup) }
        let window = vDSP.window(ofType: Float.self, usingSequence: .hanningDenormalized, count: size,
                                 isHalfWindow: false)
        let windowed = vDSP.multiply(samples, window)
        var real = [Float](repeating: 0, count: half)
        var imaginary = [Float](repeating: 0, count: half)
        var power = [Float](repeating: 0, count: half)
        real.withUnsafeMutableBufferPointer { realPointer in
            imaginary.withUnsafeMutableBufferPointer { imaginaryPointer in
                guard let realBase = realPointer.baseAddress, let imaginaryBase = imaginaryPointer.baseAddress else {
                    return
                }
                var split = DSPSplitComplex(realp: realBase, imagp: imaginaryBase)
                windowed.withUnsafeBytes { bytes in
                    guard let pairs = bytes.bindMemory(to: DSPComplex.self).baseAddress else { return }
                    vDSP_ctoz(pairs, 2, &split, 1, vDSP_Length(half))
                }
                vDSP_fft_zrip(setup, &split, 1, log2n, FFTDirection(FFT_FORWARD))
                // The DC and Nyquist terms share the first bin; neither is in the bands.
                split.imagp[0] = 0
                vDSP_zvmags(&split, 1, &power, 1, vDSP_Length(half))
            }
        }
        return power
    }

    /// 0 to 1 from a bin's power. `vDSP_fft_zrip` doubles the usual transform and the Hann window halves a
    /// sine's peak, so a full-scale sine's bin has a magnitude of size / 2.
    private func level(power: Float, size: Int) -> Float {
        let amplitude = 2 * power.squareRoot() / Float(size)
        guard amplitude > 0 else { return 0 }
        let decibels = 20 * log10(amplitude)
        return min(max((decibels - Self.floor) / -Self.floor, 0), 1)
    }
}
