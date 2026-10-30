import Accelerate

/// Real-input FFT helpers built on vDSP. `size` must be a power of two.
final class RealFFT: RealTransform {
    let size: Int
    private let log2n: vDSP_Length
    private let setup: FFTSetup
    private let halfN: Int

    init(size: Int) {
        precondition(size > 0 && (size & (size - 1)) == 0, "size must be a power of two")
        self.size = size
        self.halfN = size / 2
        self.log2n = vDSP_Length(log2(Double(size)))
        self.setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))!
    }

    deinit { vDSP_destroy_fftsetup(setup) }

    /// Magnitude spectrum, length size/2 + 1 (DC … Nyquist).
    func magnitudes(_ input: [Float]) -> [Float] {
        precondition(input.count == size)
        var real = [Float](repeating: 0, count: halfN)
        var imag = [Float](repeating: 0, count: halfN)
        var mags = [Float](repeating: 0, count: halfN + 1)

        input.withUnsafeBufferPointer { inPtr in
            real.withUnsafeMutableBufferPointer { rp in
                imag.withUnsafeMutableBufferPointer { ip in
                    var split = DSPSplitComplex(realp: rp.baseAddress!, imagp: ip.baseAddress!)

                    // Pack real signal into split-complex (even indices → real, odd → imag)
                    inPtr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: halfN) { cplx in
                        vDSP_ctoz(cplx, 2, &split, 1, vDSP_Length(halfN))
                    }

                    // Forward real FFT (in-place, packed format)
                    vDSP_fft_zrip(setup, &split, 1, log2n, FFTDirection(kFFTDirection_Forward))

                    // After vDSP_fft_zrip packed format:
                    //   real[0] = DC component (real only)
                    //   imag[0] = Nyquist component (real only, packed into imaginary slot)
                    //   real[k], imag[k] for k = 1..<halfN are the complex bins 1..halfN-1
                    //
                    // vDSP scales the result by 2x relative to a textbook DFT, so we divide by 2
                    // to get the correct single-sided magnitudes.

                    let dcVal    = abs(rp[0])    // DC: purely real
                    let nyqVal   = abs(ip[0])    // Nyquist: packed into imag[0]

                    // Zero out Nyquist from imag[0] before computing magnitudes for bins 1..halfN-1
                    ip[0] = 0.0

                    var tmp = [Float](repeating: 0, count: halfN)
                    vDSP_zvabs(&split, 1, &tmp, 1, vDSP_Length(halfN))

                    // Apply 1/2 scaling to account for vDSP's 2x scale factor
                    var half: Float = 0.5
                    vDSP_vsmul(tmp, 1, &half, &tmp, 1, vDSP_Length(halfN))

                    // Copy interior bins (1..halfN-1); bin 0 slot is DC which we set separately
                    for i in 1..<halfN { mags[i] = tmp[i] }

                    mags[0]     = dcVal  * 0.5   // DC
                    mags[halfN] = nyqVal * 0.5   // Nyquist
                }
            }
        }
        return mags
    }

    /// Generalized autocorrelation via IFFT(|X|^(2*exponent)). Returns `size` real lags.
    /// exponent 1.0 == standard autocorrelation; 0.5 == BTT default.
    func generalizedAutocorrelation(_ input: [Float], exponent: Float) -> [Float] {
        precondition(input.count == size)
        var real = [Float](repeating: 0, count: halfN)
        var imag = [Float](repeating: 0, count: halfN)
        var out  = [Float](repeating: 0, count: size)

        input.withUnsafeBufferPointer { inPtr in
            real.withUnsafeMutableBufferPointer { rp in
                imag.withUnsafeMutableBufferPointer { ip in
                    var split = DSPSplitComplex(realp: rp.baseAddress!, imagp: ip.baseAddress!)

                    // Pack and forward FFT
                    inPtr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: halfN) { cplx in
                        vDSP_ctoz(cplx, 2, &split, 1, vDSP_Length(halfN))
                    }
                    vDSP_fft_zrip(setup, &split, 1, log2n, FFTDirection(kFFTDirection_Forward))

                    // Compute |X[k]|^(2*exponent) for each bin and store as purely real.
                    //
                    // Packed format: real[0]=DC, imag[0]=Nyquist, bins 1..halfN-1 in rest.
                    // Handle DC and Nyquist specially (they are real-only).
                    let dcPower  = powf(rp[0] * rp[0], exponent)
                    let nyqPower = powf(ip[0] * ip[0], exponent)

                    for i in 1..<halfN {
                        let p = rp[i] * rp[i] + ip[i] * ip[i]
                        rp[i] = powf(p, exponent)
                        ip[i] = 0.0
                    }

                    // Restore DC and Nyquist in packed slots
                    rp[0] = dcPower
                    ip[0] = nyqPower

                    // Inverse FFT
                    vDSP_fft_zrip(setup, &split, 1, log2n, FFTDirection(kFFTDirection_Inverse))

                    // vDSP inverse zrip scale: result is multiplied by 2*N relative to
                    // the standard IDFT. Normalise by 1/(2*N).
                    var scale: Float = 1.0 / Float(2 * size)
                    vDSP_vsmul(rp.baseAddress!, 1, &scale, rp.baseAddress!, 1, vDSP_Length(halfN))
                    vDSP_vsmul(ip.baseAddress!, 1, &scale, ip.baseAddress!, 1, vDSP_Length(halfN))

                    // Unpack split-complex back to interleaved real output
                    out.withUnsafeMutableBufferPointer { op in
                        op.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: halfN) { cplx in
                            vDSP_ztoc(&split, 1, cplx, 2, vDSP_Length(halfN))
                        }
                    }
                }
            }
        }
        return out
    }
}
