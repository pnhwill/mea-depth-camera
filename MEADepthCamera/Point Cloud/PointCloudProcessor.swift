//
//  PointCloudProcessor.swift
//  MEADepthCamera
//
//  Created by Will on 7/26/21.
//

import AVFoundation
import Metal

class PointCloudProcessor {
    
    var numLandmarks: Int
    
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
    
    required init(numLandmarks: Int) {
        self.numLandmarks = numLandmarks
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
    /*
    static private func allocateOutputBuffers() {
    }
    */
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

// The following code is not implemented due to performance issues. It should be refactored into Metal shaders
/*
extension DepthDataProcessor {
    
    private func getLensDistortion(scaleX: CGFloat, scaleY: CGFloat) -> (CGPoint, [Float]) {
        // temporary method for lens distortion code
        
        // Get the distortion lookup table and center
        let distortionLookupTable = depthData?.cameraCalibrationData?.inverseLensDistortionLookupTable
        let distortionCenter = depthData?.cameraCalibrationData?.lensDistortionCenter
        // Scale the optical center to the depth map size
        let scaledDistortionCenter = CGPoint(x: distortionCenter!.x * CGFloat(scaleX), y: distortionCenter!.y * CGFloat(scaleY))
        
        // Convert lookup table to array
        // NOTE: it is bad for performance to convert the entire table to an array at each frame like this
        let lookupTableValues = distortionLookupTable!.toArray(type: Float.self)
        
        return (scaledDistortionCenter, lookupTableValues)
    }
    
    private func rectifyDepthDataMap(depthData: AVDepthData?) -> CVPixelBuffer? {
        // Method to rectify the depth data map from lens-distorted to rectilinear coordinate space
        guard let depthDataMap = depthData?.depthDataMap, let depthDataType = depthData?.depthDataType else {
            print("Depth data not found.")
            return nil
        }
        // Get the distortion lookup table and center
        guard
            let distortionLookupTable = depthData?.cameraCalibrationData?.inverseLensDistortionLookupTable,
            let distortionCenter = depthData?.cameraCalibrationData?.lensDistortionCenter else {
            return nil
        }
        
        // Convert lookup table to array
        // NOTE: it is bad for performance to convert the entire table to an array at each frame like this
        let lookupTableValues = distortionLookupTable.toArray(type: Float.self)
        
        // Get video and depth stream resolutions to convert between coordinate systems
        let depthMapWidth = CVPixelBufferGetWidth(depthDataMap)
        let depthMapHeight = CVPixelBufferGetHeight(depthDataMap)
        let depthMapSize = CGSize(width: depthMapWidth, height: depthMapHeight)
        let imageSize = self.captureDeviceResolution
        let scaleX = CGFloat(depthMapWidth) / CGFloat(imageSize.width)
        let scaleY = CGFloat(depthMapHeight) / CGFloat(imageSize.height)
        
        // Scale the optical center to the depth map size
        let scaledDistortionCenter = CGPoint(x: distortionCenter.x * scaleX, y: distortionCenter.y * scaleY)
        
        var outputBuffer: CVPixelBuffer?
        let result = CVPixelBufferCreate(nil, depthMapWidth, depthMapHeight, depthDataType, nil, &outputBuffer)
        //print(result)
        
        if result == kCVReturnSuccess && outputBuffer != nil {
            CVPixelBufferLockBaseAddress(depthDataMap, .readOnly)
            CVPixelBufferLockBaseAddress(outputBuffer!, CVPixelBufferLockFlags(rawValue: 0))
            
            let inputBytesPerRow = CVPixelBufferGetBytesPerRow(depthDataMap)
            guard let inputBaseAddress = CVPixelBufferGetBaseAddress(depthDataMap) else {
                return nil
            }
            let outputBytesPerRow = CVPixelBufferGetBytesPerRow(outputBuffer!)
            guard let outputBaseAddress = CVPixelBufferGetBaseAddress(outputBuffer!) else {
                return nil
            }
            
            // Loop over all output pixels
            for y in 0..<depthMapHeight {
                // Create pointer to output buffer
                let outputRowData = outputBaseAddress + y * outputBytesPerRow
                let outputData = UnsafeMutableBufferPointer(start: outputRowData.assumingMemoryBound(to: Float32.self), count: depthMapWidth)
                
                for x in 0..<depthMapWidth {
                    // For each output pixel, do inverse distortion transformation and clamp the points within the bounds of the buffer
                    let distortedPoint = CGPoint(x: x, y: y)
                    var correctedPoint = lensDistortionPoint(for: distortedPoint, lookupTable: lookupTableValues, distortionOpticalCenter: scaledDistortionCenter, imageSize: depthMapSize)
                    correctedPoint.clamp(bounds: depthMapSize)
                    
                    // Create pointer to input buffer
                    let inputRowData = inputBaseAddress + Int(correctedPoint.y) * inputBytesPerRow
                    let inputData = UnsafeBufferPointer(start: inputRowData.assumingMemoryBound(to: Float32.self), count: depthMapWidth)
                    
                    // Sample pixel value from input buffer and pull into output buffer
                    let pixelValue = inputData[Int(correctedPoint.x)]
                    outputData[x] = pixelValue
                }
            }
            CVPixelBufferUnlockBaseAddress(depthDataMap, .readOnly)
            CVPixelBufferUnlockBaseAddress(outputBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        } else {
            print("Failed to create output pixel buffer.")
            return nil
        }
        
        return outputBuffer
    }
    
    private func lensDistortionPoint(for point: CGPoint, lookupTable: [Float], distortionOpticalCenter opticalCenter: CGPoint, imageSize: CGSize) -> CGPoint {
        // The lookup table holds the relative radial magnification for n linearly spaced radii.
        // The first position corresponds to radius = 0
        // The last position corresponds to the largest radius found in the image.
        
        // Determine the maximum radius.
        let delta_ocx_max = Float(max(opticalCenter.x, imageSize.width  - opticalCenter.x))
        let delta_ocy_max = Float(max(opticalCenter.y, imageSize.height - opticalCenter.y))
        let r_max = sqrt(delta_ocx_max * delta_ocx_max + delta_ocy_max * delta_ocy_max)
        
        // Determine the vector from the optical center to the given point.
        let v_point_x = Float(point.x - opticalCenter.x)
        let v_point_y = Float(point.y - opticalCenter.y)
        
        // Determine the radius of the given point.
        let r_point = sqrt(v_point_x * v_point_x + v_point_y * v_point_y)
        
        // Look up the relative radial magnification to apply in the provided lookup table
        
        let magnification: Float
        //let lookupTableValues = lookupTable.toArray(type: Float.self)
        if r_point < r_max {
            // Linear interpolation
            let val   = r_point / r_max
            let idx   = Int(val)
            let frac  = val - Float(idx)
            
            let mag_1 = lookupTable[idx]
            let mag_2 = lookupTable[idx + 1]
            
            magnification = (1.0 - frac) * mag_1 + frac * mag_2
        } else {
            magnification = lookupTable.last!
        }
        
        // Deprecated implementation below, which pulls lookup table values straight from the source data.
        // NOTE: this is faster than my implementation, but I'm not sure how to update this yet.
        /*
         let magnification: Float = lookupTable.withUnsafeBytes { (lookupTableValues: UnsafePointer<Float>) in
         let lookupTableCount = lookupTable.count / MemoryLayout<Float>.size
         
         if r_point < r_max {
         // Linear interpolation
         let val   = r_point * Float(lookupTableCount - 1) / r_max
         let idx   = Int(val)
         let frac  = val - Float(idx)
         
         let mag_1 = lookupTableValues[idx]
         let mag_2 = lookupTableValues[idx + 1]
         
         return (1.0 - frac) * mag_1 + frac * mag_2
         } else {
         return lookupTableValues[lookupTableCount - 1]
         }
         }
         */
        
        // Apply radial magnification
        let new_v_point_x = v_point_x + magnification * v_point_x
        let new_v_point_y = v_point_y + magnification * v_point_y
        
        // Construct output
        return CGPoint(x: opticalCenter.x + CGFloat(new_v_point_x), y: opticalCenter.y + CGFloat(new_v_point_y))
    }
}

extension Data {
    // Method to convert from data to array
    func toArray<T>(type: T.Type) -> [T] where T: ExpressibleByIntegerLiteral {
        var array = Array<T>(repeating: 0, count: self.count/MemoryLayout<T>.stride)
        _ = array.withUnsafeMutableBytes { copyBytes(to: $0) }
        return array
    }
}

extension CGPoint {
    // Method to clamp a CGPoint within a certain bounds
    mutating func clamp(bounds: CGSize) {
        self.x = min(bounds.width, max(self.x, 0.0))
        self.y = min(bounds.height, max(self.y, 0.0))
    }
}
*/
