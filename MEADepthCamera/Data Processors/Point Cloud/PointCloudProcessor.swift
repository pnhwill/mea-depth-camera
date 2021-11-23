//
//  PointCloudProcessor.swift
//  MEADepthCamera
//
//  Created by Will on 7/26/21.
//

import AVFoundation
import Metal

/// Point cloud renderer with Metal compute kernel.
class PointCloudProcessor {
    
    let description: String = "Point Cloud Processor"
    
    var isPrepared = false
    
    private var processorSettings: ProcessorSettings
    
    private(set) var inputFormatDescription: CMFormatDescription?
    
    private var inputTextureFormat: MTLPixelFormat = .invalid
    
    private var pointCloudBuffer: MTLBuffer?
    
    private let metalDevice = MTLCreateSystemDefaultDevice()!
    
    private var computePipelineState: MTLComputePipelineState?
    
    private lazy var commandQueue: MTLCommandQueue? = {
        return self.metalDevice.makeCommandQueue()
    }()
    
    private var textureCache: CVMetalTextureCache!
    
    private var inputBufferSize: Int
    private var outputBufferSize: Int
    
    init(settings: ProcessorSettings) {
        self.processorSettings = settings
        let defaultLibrary = metalDevice.makeDefaultLibrary()!
        let kernelFunction = defaultLibrary.makeFunction(name: "pointCloudKernel")
        inputBufferSize = MemoryLayout<vector_float2>.stride * processorSettings.numLandmarks
        outputBufferSize = MemoryLayout<vector_float3>.stride * processorSettings.numLandmarks
        do {
            computePipelineState = try metalDevice.makeComputePipelineState(function: kernelFunction!)
        } catch {
            fatalError("Unable to create \(description) pipeline state. (\(error))")
        }
    }
    /*
    static private func allocateOutputBuffers() {
    }
    */
    func prepare(with formatDescription: CMFormatDescription) {
        reset()
        
        inputFormatDescription = formatDescription
        
        let inputMediaSubType = CMFormatDescriptionGetMediaSubType(formatDescription)
        if inputMediaSubType == kCVPixelFormatType_32BGRA {
            inputTextureFormat = .bgra8Unorm
        } else {
            assertionFailure("Input format not supported")
        }
        
        var metalTextureCache: CVMetalTextureCache?
        if CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, metalDevice, nil, &metalTextureCache) != kCVReturnSuccess {
            assertionFailure("Unable to allocate \(description) texture cache")
        } else {
            textureCache = metalTextureCache
        }
        
        // Create a new buffer with enough capacity to store one instance of the dynamic buffer data
        guard let outputBuffer = metalDevice.makeBuffer(length: outputBufferSize, options: [.storageModeShared]) else {
            print("Allocation failure: Could not make landmarks buffers (\(self.description))")
            return
        }
        pointCloudBuffer = outputBuffer
        
        isPrepared = true
    }
    
    func reset() {
        inputFormatDescription = nil
        textureCache = nil
        isPrepared = false
    }
    
    // MARK: Point Cloud Rendering
    
    func render(landmarks: [vector_float2], depthFrame: CVPixelBuffer) -> [vector_float3]? {
        if !isPrepared {
            assertionFailure("Invalid state: Not prepared")
            return nil
        }
        
        guard let inputTexture = makeTextureFromCVPixelBuffer(pixelBuffer: depthFrame, textureFormat: inputTextureFormat) else {
            print("Depth data input buffer not found")
            return nil
        }
        
        // Get camera instrinsics
        guard let cameraCalibrationData = (processorSettings.decodedCameraCalibrationData ?? processorSettings.cameraCalibrationData) as? CameraCalibrationDataProtocol else {
            print("\(description): Could not find camera calibration data")
            return nil
        }
        var intrinsics: float3x3 = cameraCalibrationData.intrinsicMatrix
        let referenceDimensions: CGSize = cameraCalibrationData.intrinsicMatrixReferenceDimensions
        
        // Bring focal and principal points into the same coordinate system as the depth map
        let ratio: Float = Float(referenceDimensions.width) / Float(CVPixelBufferGetWidth(depthFrame))
        intrinsics[0][0] /= ratio
        intrinsics[1][1] /= ratio
        intrinsics[2][0] /= ratio
        intrinsics[2][1] /= ratio
        
        // Set up command queue, buffer, and encoder
        guard let commandQueue = commandQueue,
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
                print("Failed to create Metal command queue")
                CVMetalTextureCacheFlush(textureCache!, 0)
                return nil
        }
        
        // Set arguments to shader
        commandEncoder.label = description
        commandEncoder.setComputePipelineState(computePipelineState!)
        commandEncoder.setBytes(landmarks, length: inputBufferSize, index: Int(BufferIndexLandmarksInput.rawValue))
        commandEncoder.setTexture(inputTexture, index: Int(TextureIndexInput.rawValue))
        commandEncoder.setBytes(&intrinsics, length: MemoryLayout<float3x3>.size, index: Int(BufferIndexCameraIntrinsicsInput.rawValue))
        commandEncoder.setBuffer(pointCloudBuffer, offset: 0, index: Int(BufferIndexPointCloudOutput.rawValue))
        
        // Set up the thread groups.
        let gridSize: MTLSize = MTLSizeMake(processorSettings.numLandmarks, 1, 1)
        var threadgroupSize = computePipelineState!.maxTotalThreadsPerThreadgroup
        if threadgroupSize > processorSettings.numLandmarks {
            threadgroupSize = processorSettings.numLandmarks
        }
        let threadsPerThreadgroup: MTLSize = MTLSizeMake(threadgroupSize, 1, 1)
        /*
        let width = computePipelineState!.threadExecutionWidth
        let height = computePipelineState!.maxTotalThreadsPerThreadgroup / width
        let threadsPerThreadgroup = MTLSizeMake(width, height, 1)
        let threadgroupsPerGrid = MTLSize(width: (inputTexture.width + width - 1) / width,
                                          height: (inputTexture.height + height - 1) / height,
                                          depth: 1)
        */
        commandEncoder.dispatchThreads(gridSize, threadsPerThreadgroup: threadsPerThreadgroup)
        
        commandEncoder.endEncoding()
        
        commandBuffer.commit()

        let outputPointer = pointCloudBuffer?.contents().assumingMemoryBound(to: vector_float3.self)
        let outputDataBufferPointer = UnsafeBufferPointer<vector_float3>(start: outputPointer, count: processorSettings.numLandmarks)
        let outputArray = Array<vector_float3>(outputDataBufferPointer)
        
        return outputArray
    }
    
    func makeTextureFromCVPixelBuffer(pixelBuffer: CVPixelBuffer, textureFormat: MTLPixelFormat) -> MTLTexture? {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        // Create a Metal texture from the image buffer
        var cvTextureOut: CVMetalTexture?
        CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, textureCache, pixelBuffer, nil, textureFormat, width, height, 0, &cvTextureOut)
        guard let cvTexture = cvTextureOut, let texture = CVMetalTextureGetTexture(cvTexture) else {
            print("\(description) failed to create preview texture")
            
            CVMetalTextureCacheFlush(textureCache, 0)
            
            return nil
        }
        
        return texture
    }
    
}
