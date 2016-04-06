// Copyright © 2016 Venture Media Labs. All rights reserved.
//
// This file is part of BrainCore. The full BrainCore copyright notice,
// including terms governing use, modification, and redistribution, is
// contained in the file LICENSE at the root of the source code distribution
// tree.

import Foundation
import Metal

/// TransposeLayer transposes input data so that elements in consecutive batches are contiguous in memory. We do this so that concatenation of layer outputs becomes concatenation of memory blocks removing the need of concat and split layers. This class does not perform matrix transposition in the general sense and therefore is an internal class to avoid confusion.
internal class TransposeLayer: ForwardLayer {
    static let metalFunctionName = "transpose"
    var metalFunction: MTLComputePipelineState!

    /// The size of each batch element
    let size: Int

    var outputSize: Int {
        return size
    }

    var inputSize: Int {
        return size
    }

    init(size: Int) {
        self.size = size
    }

    struct TransposeDimensions {
        let batchSize: UInt32
        let inputSize: UInt32
    }

    func setupInLibrary(library: MTLLibrary) throws {
        let forwardFunction = library.newFunctionWithName(TransposeLayer.metalFunctionName)!
        metalFunction = try library.device.newComputePipelineStateWithFunction(forwardFunction)
    }

    func encodeForwardInBuffer(buffer: MTLCommandBuffer, batchSize: Int, input: MTLBuffer, offset inputOffset: Int, output: MTLBuffer, offset outputOffset: Int) {
        var dimensions = TransposeDimensions(batchSize: UInt32(batchSize), inputSize: UInt32(inputSize))
        let dimensionsBuffer = buffer.device.newBufferWithBytes(&dimensions, length: sizeof(TransposeDimensions), options: .CPUCacheModeWriteCombined)
        dimensionsBuffer.label = "TransposeDimensions"

        let encoder = buffer.computeCommandEncoder()
        encoder.label = "TransposeForward"
        encoder.setComputePipelineState(metalFunction)
        encoder.setBuffer(input, offset: inputOffset * sizeof(Float), atIndex: 0)
        encoder.setBuffer(output, offset: outputOffset * sizeof(Float), atIndex: 1)
        encoder.setBuffer(dimensionsBuffer, offset: 0, atIndex: 2)

        let count = input.length / sizeof(Float)
        let threadsPerGroup = MTLSize(width: metalFunction.threadExecutionWidth, height: 1, depth: 1)
        let numThreadgroups = MTLSize(width: (count - 1) / metalFunction.threadExecutionWidth + 1, height: batchSize, depth:1)
        encoder.dispatchThreadgroups(numThreadgroups, threadsPerThreadgroup: threadsPerGroup)

        encoder.endEncoding()
    }
}
