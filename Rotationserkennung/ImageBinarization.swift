//
//  ImageThresholding.swift
//  smartCam
//
//  Created by Jonas on 28.12.19.
//  Copyright © 2019 Jonas. All rights reserved.
//

import Foundation
import CoreImage
import MetalPerformanceShaders
import Accelerate
import UIKit

class ImageBinarization {
    
    let context = CIContext(options: nil)
    
    func threshold(image: CGImage) -> UIImage? {
        
        let ciImage = CIImage(cgImage: image)

        guard let contrastImage = try? ContrastImageCreator.apply(
            withExtent: ciImage.extent,
            inputs: [ciImage],
            arguments: [:]
        ) else { return nil }
        

        guard let cgImage = saveCIImageToAlbum(ciimg: contrastImage) else {
            return nil
        }
        
        guard let t = calculateThresholdOtsu(inputImage: cgImage) else {
            return nil
        }
        
        guard let thresholdImage = try? ImageThresholdingKernel.apply(
            withExtent: contrastImage.extent,
            inputs: [contrastImage],
            arguments: ["thresholdValue": t - 0.2]
        ) else { return nil }
                                        
        let _ = saveCIImageToAlbum(ciimg: thresholdImage)
    
        guard let finalImage = try? BinarizeImageCreator.apply(
            withExtent: ciImage.extent,
            inputs: [ciImage, thresholdImage],
            arguments: [:]
        ) else { return nil }

        if let cgImage = saveCIImageToAlbum(ciimg: finalImage) {
            let uiimg = UIImage(cgImage: cgImage)
            return uiimg
        }
        
        return nil
    }
    
    func saveCIImageToAlbum(ciimg: CIImage) -> CGImage? {
        guard let cgImage = context.createCGImage(ciimg, from: ciimg.extent) else { return nil }
        //let uimg = UIImage(cgImage: cgImage)
        //UIImageWriteToSavedPhotosAlbum(uimg, self, nil, nil)
        return cgImage
    }


    func grayscale(inputImage: CGImage) -> CGImage? {
        let redCoefficient: Float = 0.2126
        let greenCoefficient: Float = 0.7152
        let blueCoefficient: Float = 0.0722

        let divisor: Int32 = 0x1000
        let fDivisor = Float(divisor)

        var coefficientsMatrix = [
            Int16(redCoefficient * fDivisor),
            Int16(greenCoefficient * fDivisor),
            Int16(blueCoefficient * fDivisor)
        ]
        
        let preBias: [Int16] = [0, 0, 0, 0]
        let postBias: Int32 = 0
        
        guard let format = vImage_CGImageFormat(cgImage: inputImage) else {
            return nil
        }
        
        guard var sourceBuffer = try? vImage_Buffer(cgImage: inputImage, format: format) else {
            return nil
        }
                
        guard var destinationBuffer = try? vImage_Buffer(
            width: Int(sourceBuffer.width),
            height: Int(sourceBuffer.height),
            bitsPerPixel: 8
        ) else {
            return nil
        }
        
        vImageMatrixMultiply_ARGB8888ToPlanar8(
            &sourceBuffer,
            &destinationBuffer,
            &coefficientsMatrix,
            divisor,
            preBias,
            postBias,
            vImage_Flags(kvImageNoFlags)
        )


        guard let monoFormat = vImage_CGImageFormat(
            bitsPerComponent: 8,
            bitsPerPixel: 8,
            colorSpace: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            renderingIntent: .defaultIntent)
        else {
            return nil
        }

        guard let result = try? destinationBuffer.createCGImage(format: monoFormat) else {
            return nil
        }

        return result
        
    }

    func calculateThresholdOtsu(inputImage: CGImage) -> Float? {
                
        guard let format = vImage_CGImageFormat(cgImage: inputImage) else {
            return nil
        }
        
        guard var sourceBuffer = try? vImage_Buffer(cgImage: inputImage, format: format) else {
            return nil
        }
        
        let histArray = [UInt](repeating: 0, count: 256)
        let histogramPointer = UnsafeMutablePointer<vImagePixelCount>(mutating: histArray)
        
        let _ = vImageHistogramCalculation_Planar8(
            &sourceBuffer,
            histogramPointer,
            vImage_Flags(kvImageNoFlags)
        )

                
        let numberOfPixels: UInt = UInt(sourceBuffer.width) * UInt(sourceBuffer.height)

        var sum_all: Float = 0
        for i in 0...255 {
            sum_all += Float( UInt(i+1) * histArray[i])
        }
        
        var count_bg: UInt = 0
        var count_fg: UInt = 0
        var sum_bg: Float = 0
        
        var varMax: Float = 0
        var threshold: Float = 0
        
        for i in 0...255 {
            count_bg += histArray[i]
            if count_bg == 0 {
                continue
            }
            
            count_fg = numberOfPixels - count_bg
            if count_fg == 0 {
                break
            }
            
            sum_bg += Float( UInt(i+1) * histArray[i])
            
            let mean_bg: Float = sum_bg / Float(count_bg)
            let mean_fg: Float = (sum_all - sum_bg) / Float(count_fg)
            
            let varBetween: Float = Float(count_bg)
                                    * Float(count_fg)
                                    * powf((mean_bg - mean_fg), 2)
            
            if varBetween > varMax {
                varMax = varBetween
                threshold = Float(i) / 256
            }
            
        }
        
        return threshold
                
    }

    
}

class ContrastImageCreator: CIImageProcessorKernel {
    
    static let device = MTLCreateSystemDefaultDevice()
    
    override class func process(
        with inputs: [CIImageProcessorInput]?,
        arguments: [String : Any]?,
        output: CIImageProcessorOutput
    ) throws {
        
        guard
            let device = device,
            let commandBuffer = output.metalCommandBuffer,
            let input = inputs?.first,
            let sourceTexture = input.metalTexture,
            let destinationTexture = output.metalTexture
        else  {
           return
        }
        
        let library = device.makeDefaultLibrary()
        let contrastShader = library?.makeFunction(name: "contrast_shader")
        
        let pipeline = try device.makeComputePipelineState(
            function: contrastShader!
        )
        
        let encoder = commandBuffer.makeComputeCommandEncoder()!
        
        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(sourceTexture, index: 0)
        encoder.setTexture(destinationTexture, index: 1)
        
        let threadGroupCount = MTLSizeMake(16, 16, 1)
        
        let tgWidth = destinationTexture.width / threadGroupCount.width
        let tgHeight = destinationTexture.height / threadGroupCount.height
        
        let threadGroup = MTLSizeMake(tgWidth, tgHeight, 1)
        
        encoder.dispatchThreadgroups(
            threadGroup,
            threadsPerThreadgroup: threadGroupCount
        )
        encoder.endEncoding()
        
        
    }
    
}


class CharFiller: CIImageProcessorKernel {
    
    static let device = MTLCreateSystemDefaultDevice()
    
    override class func process(with inputs: [CIImageProcessorInput]?, arguments: [String : Any]?, output: CIImageProcessorOutput) throws {
        guard
            let device = device,
            let commandBuffer = output.metalCommandBuffer,
            let input = inputs?.first,
            let sourceTexture = input.metalTexture,
            let destinationTexture = output.metalTexture
        else  {
           return
        }
        
        let library = device.makeDefaultLibrary()
        let computeShader = library?.makeFunction(name: "fill_char_shader")
        
        let pipeline = try device.makeComputePipelineState(function: computeShader!)
        
        let encoder = commandBuffer.makeComputeCommandEncoder()!
        
        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(sourceTexture, index: 0)
        encoder.setTexture(destinationTexture, index: 1)
        
        let threadGroupCount = MTLSizeMake(16, 16, 1)
        let threadGroup = MTLSizeMake(destinationTexture.width / threadGroupCount.width,
                                      destinationTexture.height / threadGroupCount.height,
                                      1)
        
        encoder.dispatchThreadgroups(threadGroup, threadsPerThreadgroup: threadGroupCount)
        encoder.endEncoding()
        
        
    }
    
}

class BinarizeImageCreator: CIImageProcessorKernel {
    
    static let device = MTLCreateSystemDefaultDevice()
    
    override class func process(with inputs: [CIImageProcessorInput]?, arguments: [String : Any]?, output: CIImageProcessorOutput) throws {
        guard
            let device = device,
            let commandBuffer = output.metalCommandBuffer,
            let input = inputs?.first,
            let contrast = inputs?[1],
            let sourceTexture = input.metalTexture,
            let contrastImg = contrast.metalTexture,
            let destinationTexture = output.metalTexture
        else  {
           return
        }
        
        let library = device.makeDefaultLibrary()
        let computeShader = library?.makeFunction(name: "binarize_shader")
        
        let pipeline = try device.makeComputePipelineState(function: computeShader!)
        
        let encoder = commandBuffer.makeComputeCommandEncoder()!
        
        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(sourceTexture, index: 0)
        encoder.setTexture(destinationTexture, index: 2)
        encoder.setTexture(contrastImg, index: 1)
        
        let threadGroupCount = MTLSizeMake(16, 16, 1)
        let threadGroup = MTLSizeMake(destinationTexture.width / threadGroupCount.width,
                                      destinationTexture.height / threadGroupCount.height,
                                      1)
        
        encoder.dispatchThreadgroups(threadGroup, threadsPerThreadgroup: threadGroupCount)
        encoder.endEncoding()
        
        
    }
    
}

class ImageThresholdingKernel: CIImageProcessorKernel {
    
    static let device = MTLCreateSystemDefaultDevice()
    
    override class func process(
        with inputs: [CIImageProcessorInput]?,
        arguments: [String : Any]?,
        output: CIImageProcessorOutput
    ) throws {
        
        guard
            let device = device,
            let commandBuffer = output.metalCommandBuffer,
            let input = inputs?.first,
            let sourceTexture = input.metalTexture,
            let destinationTexture = output.metalTexture,
            let thresholdValue = arguments?["thresholdValue"] as? Float
        else  {
           return
        }
                                
        let threshold = MPSImageThresholdBinary(
            device: device,
            thresholdValue: thresholdValue,
            maximumValue: 1.0,
            linearGrayColorTransform: nil
        )
        
        threshold.encode(
            commandBuffer: commandBuffer,
            sourceTexture: sourceTexture,
            destinationTexture: destinationTexture
        )
        
    }
    
}

class DilateKernel: CIImageProcessorKernel {
    
    static let device = MTLCreateSystemDefaultDevice()
    
    override class func process(with inputs: [CIImageProcessorInput]?, arguments: [String : Any]?, output: CIImageProcessorOutput) throws {
        guard
            let device = device,
            let commandBuffer = output.metalCommandBuffer,
            let input = inputs?.first,
            let sourceTexture = input.metalTexture,
            let destinationTexture = output.metalTexture
        else  {
           return
        }
                
        let weights: [Float] = [0.5, 0.5, 0.5, 0.5, 0.5,
                                0.5, 0.5, 0.5, 0.5, 0.5,
                                0.5, 0.5,   0, 0.5, 0.5,
                                0.5, 0.5, 0.5, 0.5, 0.5,
                                0.5, 0.5, 0.5, 0.5, 0.5]
        
        let dilate = MPSImageDilate(
            device: device,
            kernelWidth: 9,
            kernelHeight: 9,
            values: weights
        )
                
        dilate.encode(
            commandBuffer: commandBuffer,
            sourceTexture: sourceTexture,
            destinationTexture: destinationTexture
        )
        
    }
    
}

class ErodeKernel: CIImageProcessorKernel {
    
    static let device = MTLCreateSystemDefaultDevice()
    
    override class func process(with inputs: [CIImageProcessorInput]?, arguments: [String : Any]?, output: CIImageProcessorOutput) throws {
        guard
            let device = device,
            let commandBuffer = output.metalCommandBuffer,
            let input = inputs?.first,
            let sourceTexture = input.metalTexture,
            let destinationTexture = output.metalTexture
        else  {
           return
        }
                
//        let weights: [Float] = [0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3,
//                                0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3,
//                                0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3,
//                                0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3,
//                                0.3, 0.3, 0.3, 0.3, 0, 0.3, 0.3, 0.3, 0.3,
//                                0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3,
//                                0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3,
//                                0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3,
//                                0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3]

                
        let weights: [Float] = [0.5, 0.5, 0.5, 0.5, 0.5,
                                0.5, 0.5, 0.5, 0.5, 0.5,
                                0.5, 0.5,   0, 0.5, 0.5,
                                0.5, 0.5, 0.5, 0.5, 0.5,
                                0.5, 0.5, 0.5, 0.5, 0.5]

        
        let erode = MPSImageErode(
            device: device,
            kernelWidth: 9,
            kernelHeight: 9,
            values: weights
        )
                

        erode.encode(
            commandBuffer: commandBuffer,
            sourceTexture: sourceTexture,
            destinationTexture: destinationTexture
        )
        
    }
    
}
