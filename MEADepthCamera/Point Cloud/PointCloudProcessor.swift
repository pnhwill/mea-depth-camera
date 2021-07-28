//
//  PointCloudProcessor.swift
//  MEADepthCamera
//
//  Created by Will on 7/26/21.
//

import AVFoundation
import Metal

class PointCloudProcessor {
    
    let numLandmarks = 76
    
    var description: String = "Point Cloud Processor"
    
    var isPrepared = false
    
    private(set) var inputFormatDescription: CMFormatDescription?
    
    private var inputTextureFormat: MTLPixelFormat = .invalid
    
    private var pointCloudBuffer: MTLBuffer?
    
    private let metalDevice = MTLCreateSystemDefaultDevice()!
    
    private var computePipelineState: MTLComputePipelineState?
    
    private lazy var commandQueue: MTLCommandQueue? = {
        return self.metalDevice.makeCommandQueue()
    }()
    
    private var textureCache: CVMetalTextureCache!
    
    var inputBufferSize: Int
    var outputBufferSize: Int
    
    required init() {
        let defaultLibrary = metalDevice.makeDefaultLibrary()!
        let kernelFunction = defaultLibrary.makeFunction(name: "pointCloudKernel")
        do {
            computePipelineState = try metalDevice.makeComputePipelineState(function: kernelFunction!)
        } catch {
            fatalError("Unable to create depth converter pipeline state. (\(error))")
        }
        inputBufferSize = MemoryLayout<vector_float2>.stride * numLandmarks
        outputBufferSize = MemoryLayout<vector_float3>.stride * numLandmarks
    }
    
    static private func allocateOutputBuffers() {
        
    }
    
    func prepare(with formatDescription: CMFormatDescription) {
        reset()
        
        inputFormatDescription = formatDescription
        
        let inputMediaSubType = CMFormatDescriptionGetMediaSubType(formatDescription)
        if inputMediaSubType == kCVPixelFormatType_DepthFloat16 ||
            inputMediaSubType == kCVPixelFormatType_DisparityFloat16 {
            inputTextureFormat = .r16Float
        } else if inputMediaSubType == kCVPixelFormatType_DepthFloat32 ||
            inputMediaSubType == kCVPixelFormatType_DisparityFloat32 {
            inputTextureFormat = .r32Float
        } else {
            assertionFailure("Input format not supported")
        }
        
        var metalTextureCache: CVMetalTextureCache?
        if CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, metalDevice, nil, &metalTextureCache) != kCVReturnSuccess {
            assertionFailure("Unable to allocate depth converter texture cache")
        } else {
            textureCache = metalTextureCache
        }
        
        // Set up input and output buffers
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
    func render(landmarks: [vector_float2], depthData: AVDepthData) {
        if !isPrepared {
            assertionFailure("Invalid state: Not prepared")
            return
        }
        
        let depthFrame: CVPixelBuffer = depthData.depthDataMap
        
        guard let inputTexture = makeTextureFromCVPixelBuffer(pixelBuffer: depthFrame, textureFormat: inputTextureFormat) else {
            print("Depth data input buffer not found")
            return
        }
        
        // Get camera instrinsics
        guard var intrinsics: float3x3 = depthData.cameraCalibrationData?.intrinsicMatrix,
              let referenceDimensions: CGSize = depthData.cameraCalibrationData?.intrinsicMatrixReferenceDimensions else {
            print("Could not find camera calibration data")
            return
        }
        
        // Bring focal and principal points into the same coordinate system as the depth map
        let ratio: Float = Float(referenceDimensions.width) / Float(CVPixelBufferGetWidth(depthFrame))
        intrinsics[0][0] /= ratio
        intrinsics[1][1] /= ratio
        intrinsics[2][0] /= ratio
        intrinsics[2][1] /= ratio
        
        

        //let inputBuffer = metalDevice.makeBuffer(bytes: landmarks, length: inputBufferSize, options: [])


        // Set up command queue, buffer, and encoder
        guard let commandQueue = commandQueue,
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
                print("Failed to create Metal command queue")
                CVMetalTextureCacheFlush(textureCache!, 0)
                return
        }
        
        // Set arguments to shader
        commandEncoder.label = description
        commandEncoder.setComputePipelineState(computePipelineState!)
        commandEncoder.setBytes(landmarks, length: inputBufferSize, index: Int(BufferIndexLandmarksInput.rawValue))
        commandEncoder.setTexture(inputTexture, index: Int(TextureIndexDepthInput.rawValue))
        commandEncoder.setBytes(&intrinsics, length: MemoryLayout<float3x3>.size, index: Int(BufferIndexCameraIntrinsicsInput.rawValue))
        commandEncoder.setBuffer(pointCloudBuffer, offset: 0, index: Int(BufferIndexPointCloudOutput.rawValue))
        
        // Set up the thread groups.
        let gridSize: MTLSize = MTLSizeMake(numLandmarks, 1, 1)
        var threadgroupSize = computePipelineState!.maxTotalThreadsPerThreadgroup
        if threadgroupSize > numLandmarks {
            threadgroupSize = numLandmarks
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

        //let outputArray = outputBuffer.contents()//.assumingMemoryBound(to: [vector_float3].self).pointee
    }
    
    func getOutput(index: Int) -> vector_float3? {
        guard let output: UnsafeMutableRawPointer = pointCloudBuffer?.contents() else {
            print("Output buffer not found")
            return nil
        }
        
        return output.load(fromByteOffset: MemoryLayout<vector_float3>.stride, as: vector_float3.self)
    }
    
    func makeTextureFromCVPixelBuffer(pixelBuffer: CVPixelBuffer, textureFormat: MTLPixelFormat) -> MTLTexture? {
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
