//
//  LensDistortionCorrectionProcessor.swift
//  MEADepthCamera
//
//  Created by Will on 11/29/21.
//

import CoreMedia
import Metal

/// Image processor that performs lens distortion correction.
class LensDistortionCorrectionProcessor: FilterRenderer {
    
    let description: String = "Lens Distortion Correction Processor"
    private(set) var isPrepared = false
    private(set) var outputFormatDescription: CMFormatDescription?
    private(set) var inputFormatDescription: CMFormatDescription?
    
    private var settings: ProcessorSettings
    
    private var inputTextureFormat: MTLPixelFormat = .invalid
    private var outputPixelBufferPool: CVPixelBufferPool?
    private let metalDevice = MTLCreateSystemDefaultDevice()!
    private var computePipelineState: MTLComputePipelineState?
    private lazy var commandQueue: MTLCommandQueue? = {
        return self.metalDevice.makeCommandQueue()
    }()
    private var textureCache: CVMetalTextureCache!
    
    required init(settings: ProcessorSettings) {
        self.settings = settings
        loadMetal()
    }
    
    // MARK: Prepare
    func prepare(with inputFormatDescription: CMFormatDescription, outputRetainedBufferCountHint: Int) {
        reset()
        
        (outputPixelBufferPool, _, outputFormatDescription) = allocateOutputBufferPool(with: inputFormatDescription, outputRetainedBufferCountHint: outputRetainedBufferCountHint)
        if outputPixelBufferPool == nil {
            return
        }
        self.inputFormatDescription = inputFormatDescription
        
        let inputMediaSubType = CMFormatDescriptionGetMediaSubType(inputFormatDescription)
        if inputMediaSubType == kCVPixelFormatType_32BGRA {
            inputTextureFormat = .bgra8Unorm
        } else {
            assertionFailure("Input format not supported")
        }
        
        var metalTextureCache: CVMetalTextureCache?
        if CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, metalDevice, nil, &metalTextureCache) != kCVReturnSuccess {
            assertionFailure("Unable to allocate \(description) texture cache.")
        } else {
            textureCache = metalTextureCache
        }
        
        isPrepared = true
    }
    
    func reset() {
        outputPixelBufferPool = nil
        outputFormatDescription = nil
        inputFormatDescription = nil
        textureCache = nil
        isPrepared = false
    }
    
    // MARK: Render
    func render(pixelBuffer: CVPixelBuffer) -> CVPixelBuffer? {
        if !isPrepared {
            assertionFailure("Invalid state: \(description) not prepared.")
            return nil
        }
        
        var newPixelBuffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, outputPixelBufferPool!, &newPixelBuffer)
        guard let outputPixelBuffer = newPixelBuffer else {
            print("Allocation failure: Could not get pixel buffer from pool (\(description))")
            return nil
        }
        
        guard let outputTexture = makeTextureFromCVPixelBuffer(pixelBuffer: outputPixelBuffer, textureFormat: inputTextureFormat),
              let inputTexture = makeTextureFromCVPixelBuffer(pixelBuffer: pixelBuffer, textureFormat: inputTextureFormat) else {
                  return nil
        }
        
        // Set up command queue, buffer, and encoder.
        guard let commandQueue = commandQueue,
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
                print("Failed to create Metal command queue (\(description))")
                CVMetalTextureCacheFlush(textureCache!, 0)
                return nil
        }
        
        // Get camera calibration data
        guard let cameraCalibrationData = (settings.decodedCameraCalibrationData ?? settings.cameraCalibrationData) as? CameraCalibrationDataProtocol,
              var lookupTable = cameraCalibrationData.inverseLensDistortionLookupTable else {
            print("\(description): Could not find camera calibration data")
            return nil
        }
        
        let opticalCenter = vector_float2(Float(cameraCalibrationData.lensDistortionCenter.x), Float(cameraCalibrationData.lensDistortionCenter.y))
        let lookupTableCount = UInt(lookupTable.count / MemoryLayout<Float32>.size)
        
        var lensDistortionParameters = LensDistortionParameters(opticalCenter: opticalCenter, lookupTableCount: lookupTableCount)
//        var lookupTablePointer = UnsafeBufferPointer<Float32>(_empty: ())
//        lookupTable.withUnsafeBytes { bytes in
//            lookupTablePointer = UnsafeBufferPointer<Float32>(start: bytes.baseAddress?.assumingMemoryBound(to: Float32.self), count: Int(lookupTableCount))
//        }
        
        // Set arguments to shader.
        commandEncoder.label = description
        commandEncoder.setComputePipelineState(computePipelineState!)
        commandEncoder.setTexture(inputTexture, index: Int(TextureIndexInput.rawValue))
        commandEncoder.setTexture(outputTexture, index: Int(TextureIndexOutput.rawValue))
        commandEncoder.setBytes(&lensDistortionParameters, length: MemoryLayout.size(ofValue: lensDistortionParameters), index: Int(BufferIndexLensDistortionParameters.rawValue))
        commandEncoder.setBytes(&lookupTable, length: MemoryLayout.size(ofValue: lookupTable), index: Int(BufferIndexLookupTable.rawValue))
        
        // Set up the thread groups.
        let width = computePipelineState!.threadExecutionWidth
        let height = computePipelineState!.maxTotalThreadsPerThreadgroup / width
        let threadsPerThreadgroup = MTLSizeMake(width, height, 1)
        let threadgroupsPerGrid = MTLSize(width: (inputTexture.width + width - 1) / width,
                                          height: (inputTexture.height + height - 1) / height,
                                          depth: 1)
        commandEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        
        commandEncoder.endEncoding()
        
        commandBuffer.commit()
        
        return outputPixelBuffer
    }
}

// MARK: Private Methods
extension LensDistortionCorrectionProcessor {
    
    private static let computeFunctionName = "lensDistortionCorrection"
    
    private func loadMetal() {
        let defaultLibrary = metalDevice.makeDefaultLibrary()!
        let kernelFunction = defaultLibrary.makeFunction(name: Self.computeFunctionName)
        do {
            computePipelineState = try metalDevice.makeComputePipelineState(function: kernelFunction!)
        } catch {
            fatalError("Unable to create \(description) pipeline state. (\(error))")
        }
    }
    
    private func makeTextureFromCVPixelBuffer(pixelBuffer: CVPixelBuffer, textureFormat: MTLPixelFormat) -> MTLTexture? {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        // Create a Metal texture from the image buffer
        var cvTextureOut: CVMetalTexture?
        CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, textureCache, pixelBuffer, nil, textureFormat, width, height, 0, &cvTextureOut)
        guard let cvTexture = cvTextureOut, let texture = CVMetalTextureGetTexture(cvTexture) else {
            print("Depth converter failed to create preview texture")
            
            CVMetalTextureCacheFlush(textureCache, 0)
            
            return nil
        }
        
        return texture
    }
}
