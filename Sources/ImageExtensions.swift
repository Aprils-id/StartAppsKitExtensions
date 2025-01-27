//
//  ImageExtensions.swift
//  StartAppsKit
//
//  Created by Gabriel Lanata on 11/16/14.
//  Credits to Alexey Globchastyy
//  Copyright (c) 2014 StartApps. All rights reserved.
//

#if os(iOS)
    
    import UIKit
    import Accelerate
    
    public extension UIImage {
        
        public func applyLightEffect() -> UIImage? {
            return applyBlurWithRadius(30, tintColor: UIColor(white: 1.0, alpha: 0.3), saturationDeltaFactor: 1.8)
        }
        
        public func applyExtraLightEffect() -> UIImage? {
            return applyBlurWithRadius(20, tintColor: UIColor(white: 0.97, alpha: 0.82), saturationDeltaFactor: 1.8)
        }
        
        public func applyDarkEffect() -> UIImage? {
            return applyBlurWithRadius(20, tintColor: UIColor(white: 0.11, alpha: 0.73), saturationDeltaFactor: 1.8)
        }
        
        public func applyTintEffectWithColor(_ tintColor: UIColor) -> UIImage? {
            let effectColorAlpha: CGFloat = 0.6
            var effectColor = tintColor
            
            let componentCount = tintColor.cgColor.numberOfComponents
            
            if componentCount == 2 {
                var b: CGFloat = 0
                if tintColor.getWhite(&b, alpha: nil) {
                    effectColor = UIColor(white: b, alpha: effectColorAlpha)
                }
            } else {
                var red: CGFloat = 0
                var green: CGFloat = 0
                var blue: CGFloat = 0
                
                if tintColor.getRed(&red, green: &green, blue: &blue, alpha: nil) {
                    effectColor = UIColor(red: red, green: green, blue: blue, alpha: effectColorAlpha)
                }
            }
            
            return applyBlurWithRadius(10, tintColor: effectColor, saturationDeltaFactor: -1.0, maskImage: nil)
        }
        
        public func applyBlurWithRadius(_ blurRadius: CGFloat, tintColor: UIColor?, saturationDeltaFactor: CGFloat, maskImage: UIImage? = nil) -> UIImage? {
            // Check pre-conditions.
            if (size.width < 1 || size.height < 1) {
                print("*** error: invalid size: \(size.width) x \(size.height). Both dimensions must be >= 1: \(self)")
                return nil
            }
            if self.cgImage == nil {
                print("*** error: image must be backed by a CGImage: \(self)")
                return nil
            }
            if maskImage != nil && maskImage!.cgImage == nil {
                print("*** error: maskImage must be backed by a CGImage: \(maskImage!)")
                return nil
            }
            
            let __FLT_EPSILON__ = CGFloat(Float.ulpOfOne)
            let screenScale = UIScreen.main.scale
            let imageRect = CGRect(origin: CGPoint.zero, size: size)
            var effectImage = self
            
            let hasBlur = blurRadius > __FLT_EPSILON__
            let hasSaturationChange = abs(saturationDeltaFactor - 1.0) > __FLT_EPSILON__
            
            if hasBlur || hasSaturationChange {
                func createEffectBuffer(_ context: CGContext) -> vImage_Buffer {
                    let data = context.data
                    let width = vImagePixelCount(context.width)
                    let height = vImagePixelCount(context.height)
                    let rowBytes = context.bytesPerRow
                    
                    return vImage_Buffer(data: data, height: height, width: width, rowBytes: rowBytes)
                }
                
                UIGraphicsBeginImageContextWithOptions(size, false, screenScale)
                let effectInContext = UIGraphicsGetCurrentContext()
                
                effectInContext!.scaleBy(x: 1.0, y: -1.0)
                effectInContext!.translateBy(x: 0, y: -size.height)
                effectInContext!.draw(self.cgImage!, in: imageRect)
                
                var effectInBuffer = createEffectBuffer(effectInContext!)
                
                
                UIGraphicsBeginImageContextWithOptions(size, false, screenScale)
                let effectOutContext = UIGraphicsGetCurrentContext()
                
                var effectOutBuffer = createEffectBuffer(effectOutContext!)
                
                
                if hasBlur {
                    
                    let inputRadius = blurRadius * screenScale
                    let piRoot = CGFloat(sqrt(2 * Double.pi))
                    let pisomething2 = 3.0 * piRoot / 4
                    var radius = UInt32(floor(inputRadius * pisomething2 + 0.5))
                    if radius % 2 != 1 {
                        radius += UInt32(1.0) // force radius to be odd so that the three box-blur methodology works.
                    }
                    
                    let imageEdgeExtendFlags = vImage_Flags(kvImageEdgeExtend)
                    
                    vImageBoxConvolve_ARGB8888(&effectInBuffer, &effectOutBuffer, nil, 0, 0, radius, radius, nil, imageEdgeExtendFlags)
                    vImageBoxConvolve_ARGB8888(&effectOutBuffer, &effectInBuffer, nil, 0, 0, radius, radius, nil, imageEdgeExtendFlags)
                    vImageBoxConvolve_ARGB8888(&effectInBuffer, &effectOutBuffer, nil, 0, 0, radius, radius, nil, imageEdgeExtendFlags)
                }
                
                var effectImageBuffersAreSwapped = false
                
                if hasSaturationChange {
                    let s: CGFloat = saturationDeltaFactor
                    let floatingPointSaturationMatrix: [CGFloat] = [
                        0.0722 + 0.9278 * s,  0.0722 - 0.0722 * s,  0.0722 - 0.0722 * s,  0,
                        0.7152 - 0.7152 * s,  0.7152 + 0.2848 * s,  0.7152 - 0.7152 * s,  0,
                        0.2126 - 0.2126 * s,  0.2126 - 0.2126 * s,  0.2126 + 0.7873 * s,  0,
                        0,                    0,                    0,  1
                    ]
                    
                    let divisor: CGFloat = 256
                    let matrixSize = floatingPointSaturationMatrix.count
                    var saturationMatrix = [Int16](repeating: 0, count: matrixSize)
                    
                    for i: Int in 0 ..< matrixSize {
                        saturationMatrix[i] = Int16(round(floatingPointSaturationMatrix[i] * divisor))
                    }
                    
                    if hasBlur {
                        vImageMatrixMultiply_ARGB8888(&effectOutBuffer, &effectInBuffer, saturationMatrix, Int32(divisor), nil, nil, vImage_Flags(kvImageNoFlags))
                        effectImageBuffersAreSwapped = true
                    } else {
                        vImageMatrixMultiply_ARGB8888(&effectInBuffer, &effectOutBuffer, saturationMatrix, Int32(divisor), nil, nil, vImage_Flags(kvImageNoFlags))
                    }
                }
                
                if !effectImageBuffersAreSwapped {
                    effectImage = UIGraphicsGetImageFromCurrentImageContext()!
                }
                
                UIGraphicsEndImageContext()
                
                if effectImageBuffersAreSwapped {
                    effectImage = UIGraphicsGetImageFromCurrentImageContext()!
                }
                
                UIGraphicsEndImageContext()
            }
            
            // Set up output context.
            UIGraphicsBeginImageContextWithOptions(size, false, screenScale)
            let outputContext = UIGraphicsGetCurrentContext()
            outputContext!.scaleBy(x: 1.0, y: -1.0)
            outputContext!.translateBy(x: 0, y: -size.height)
            
            // Draw base image.
            outputContext!.draw(self.cgImage!, in: imageRect)
            
            // Draw effect image.
            if hasBlur {
                outputContext!.saveGState()
                if let image = maskImage {
                    outputContext!.clip(to: imageRect, mask: image.cgImage!);
                }
                outputContext!.draw(effectImage.cgImage!, in: imageRect)
                outputContext!.restoreGState()
            }
            
            // Add in color tint.
            if let color = tintColor {
                outputContext!.saveGState()
                outputContext!.setFillColor(color.cgColor)
                outputContext!.fill(imageRect)
                outputContext!.restoreGState()
            }
            
            // Output image is ready.
            let outputImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            return outputImage
        }
        
    }
    
    public enum ImageResizeMode {
        case stretch, minSize, maxSize, aspectFill
    }
    
    public extension UIImage {
    
        public func sizeWithLimits(width: CGFloat? = nil, height: CGFloat? = nil) -> CGSize {
            let imageSize = size
            if let width = width, height == nil {
                let ratio = imageSize.width/width
                let newHeight = imageSize.height/ratio
                return CGSize(width: width, height: newHeight)
            } else if let height = height, width == nil {
                let ratio = imageSize.height/height
                let newWidth = imageSize.width/ratio
                return CGSize(width: height, height: newWidth)
            }
            return imageSize
        }
        
        public func resize(size targetSize: CGSize, mode: ImageResizeMode = .stretch) -> UIImage {
            let contextSize: CGSize
            let drawSize: CGSize
            var drawOrigin: CGPoint = CGPoint.zero
            switch mode {
            case .stretch:
                contextSize = targetSize
                drawSize = targetSize
            case .minSize:
                let widthRatio    = targetSize.width  / self.size.width
                let heightRatio   = targetSize.height / self.size.height
                let scalingFactor = max(widthRatio, heightRatio)
                drawSize = CGSize(width:  self.size.width  * scalingFactor,
                                  height: self.size.height * scalingFactor)
                contextSize = drawSize
            case .maxSize:
                contextSize = targetSize
                drawSize = targetSize
            case .aspectFill:
                let widthRatio    = targetSize.width  / self.size.width
                let heightRatio   = targetSize.height / self.size.height
                let scalingFactor = max(widthRatio, heightRatio)
                drawSize = CGSize(width:  self.size.width  * scalingFactor,
                                  height: self.size.height * scalingFactor)
                drawOrigin = CGPoint(x: (targetSize.width  - drawSize.width)  / 2,
                                     y: (targetSize.height - drawSize.height) / 2)
                contextSize = targetSize
            }
            UIGraphicsBeginImageContext(contextSize);
            self.draw(in: CGRect(origin: drawOrigin, size: drawSize))
            let newImage = UIGraphicsGetImageFromCurrentImageContext()!
            UIGraphicsEndImageContext()
            return newImage
        }
        
        public func resize(percentage: CGFloat) -> UIImage {
            let newSize = CGSize(width: size.width * percentage, height: size.height * percentage)
            return resize(size: newSize)
        }
        
    }
    
    public extension UIImage {
        
        public var hasAlpha: Bool {
            let alpha = cgImage!.alphaInfo
            return (alpha == .first ||
                alpha == .last ||
                alpha == .premultipliedFirst ||
                alpha == .premultipliedLast)
        }
        
        public var dataUri: String {
            let imageData: Data
            let mimeType: String
            if hasAlpha {
                imageData = self.pngData()!
                mimeType = "image/png"
            } else {
                imageData = self.jpegData(compressionQuality: 0.8)!
                mimeType = "image/jpeg"
            }
            let imageDataString = imageData.base64EncodedString()
            return "data:\(mimeType);base64,\(imageDataString)"
        }
        
        public var jpegDataUri: String {
            let imageData = self.jpegData(compressionQuality: 0.8)!
            let mimeType = "image/jpeg"
            let imageDataString = imageData.base64EncodedString()
            return "data:\(mimeType);base64,\(imageDataString)"
        }
    }
    
    public extension UIView {
        
        public func contentsAsImage() -> UIImage {
            UIGraphicsBeginImageContextWithOptions(frame.size, true, UIScreen.main.scale)
            drawHierarchy(in: frame, afterScreenUpdates: false)
            let sourceImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            return sourceImage!
        }
        
    }
    
#endif
