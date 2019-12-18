//
//  TZImageCropManager.swift
//  TZImagePickerController
//
//  Created by guozw3 on 2019/11/19.
//  Copyright © 2019 centaline. All rights reserved.
//

import UIKit
import ImageIO

class TZImageCropManager: NSObject {
    
    /// 裁剪框背景的处理
    /// - Parameters:
    ///   - view: 裁剪的view
    ///   - cropRect: 裁剪的范围
    ///   - containerView: 假如是圆形裁剪需要在背景中心
    ///   - needCircleCrop: 圆形裁剪
    static func overlayClipping(with view: UIView, cropRect: CGRect, containerView: UIView, needCircleCrop: Bool) {
        let bezier = UIBezierPath.init(rect: UIScreen.main.bounds)
        let layer = CAShapeLayer()
        if needCircleCrop {
            bezier.append(UIBezierPath.init(arcCenter: containerView.center, radius: cropRect.size.width / 2, startAngle: 0, endAngle: CGFloat.pi*2, clockwise: false))
        } else {
            bezier.append(UIBezierPath.init(rect: cropRect))
        }
        layer.path = bezier.cgPath
        layer.fillRule = .evenOdd
        layer.fillColor = UIColor.black.cgColor
        layer.opacity = 0.5
        view.layer.addSublayer(layer)
    }
    
    static func cropImageView(_ imageView: UIImageView, to rect: CGRect,to zoomScale: CGFloat,from containerView: UIView) -> UIImage? {
        var transform: CGAffineTransform = .identity
        let imageViewRect: CGRect = imageView.convert(imageView.bounds, to: containerView)
        let point = CGPoint(x: imageViewRect
            .origin.x + imageViewRect.size.width/2, y: imageViewRect.origin.y + imageViewRect.size.height / 2)
        let xMargin = containerView.tz_width - rect.maxX - rect.origin.x
        let zeroPoint = CGPoint(x: (containerView.tz_width - xMargin)/2, y: containerView.center.y)
        let translation = CGPoint(x:point.x - zeroPoint.x, y: zeroPoint.y)
        transform = CGAffineTransform.init(translationX: translation.x, y: translation.y)
        //缩放
        transform = CGAffineTransform.init(scaleX: CGFloat(zoomScale), y: CGFloat(zoomScale))
        if let image = imageView.image, let cgimage = image.cgImage,
            let imageRef: CGImage = self.newTransformedImage(transform: transform, sourceImage: cgimage,
            sourceSize: image.size,
            outputWidth: rect.size.width * UIScreen.main.scale,
            cropSize: rect.size,
            imageViewSize: imageView.frame.size) {
            var cropedImage = UIImage.init(cgImage: imageRef)
            cropedImage = TZImageManager.manager.fixOrientation(image: cropedImage)
            return cropedImage
        }
        return nil
    }
    
    private static func newTransformedImage(transform: CGAffineTransform, sourceImage:CGImage, sourceSize: CGSize, outputWidth: CGFloat, cropSize: CGSize, imageViewSize: CGSize) -> CGImage? {
        guard let source: CGImage = TZImageCropManager.newScaledImage(source: sourceImage, to: sourceSize) else { return nil }
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        
        let aspect: CGFloat = cropSize.height/cropSize.width
        let outputSize = CGSize(width: outputWidth, height: outputWidth*aspect)
        
        let context = CGContext.init(data: nil, width: Int(outputSize.width), height: Int(outputSize.height), bitsPerComponent: source.bitsPerComponent, bytesPerRow: 0, space: source.colorSpace ?? rgbColorSpace, bitmapInfo: source.bitmapInfo.rawValue)
        context?.setFillColor(UIColor.clear.cgColor)
        context?.fill(CGRect(x: 0, y: 0, width: outputSize.width, height: outputSize.height))
        let uiCoords = CGAffineTransform.init(scaleX: outputSize.width / cropSize.width, y: outputSize.height / cropSize.height)
        uiCoords.translatedBy(x: cropSize.width/2, y: cropSize.height/2)
        uiCoords.scaledBy(x: 1.0, y: -1.0)
        context?.concatenate(uiCoords)
        context?.concatenate(transform)
        context?.scaleBy(x: 1.0, y: -1.0)
        
        context?.draw(source, in: CGRect(x: -imageViewSize.width/2, y: -imageViewSize.height/2, width: imageViewSize.width, height: imageViewSize.height))
        let resultCGImg = context?.makeImage()
        return resultCGImg
    }
    
    private static func newScaledImage(source: CGImage, to size: CGSize) -> CGImage? {
        let srcSize = size
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext.init(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 0, space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)
        
        context?.interpolationQuality = .none
        context?.translateBy(x: size.width/2, y: size.height/2)
        context?.draw(source, in: CGRect(x: -srcSize.width/2, y: -srcSize.height/2, width: srcSize.width, height: srcSize.height))
        
        let result = context?.makeImage()
        
        return result
    }
    
    static func circularClipImage(_ image:UIImage) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(image.size, false, UIScreen.main.scale)
        
        let ctx = UIGraphicsGetCurrentContext()
        let rect = CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
        ctx?.addEllipse(in: rect)
        ctx?.clip()
        
        image.draw(in: rect)
        let circleImage = UIGraphicsGetImageFromCurrentImageContext()
        
        UIGraphicsEndImageContext()
        return circleImage
    }
}


extension UIImage {
    static func sd_tz_animatedGIF(with data:Data) -> UIImage? {
        
        var animatedImage: UIImage?
        
        if let source = CGImageSourceCreateWithData(data as CFData, nil) {
            let count: size_t = CGImageSourceGetCount(source)
            var duration: TimeInterval = 0
            if count <= 1 {
                animatedImage = UIImage.init(data: data)
            } else {
                let maxCount = TZImagePickerConfig.sharedInstance.gifPreviewMaxImagesCount
                let interval = Int(max(((count + maxCount)/2)/maxCount, 1))
                
                var imageArr: Array<UIImage> = []
                
                for index in 0...count {
                    if let image = CGImageSourceCreateImageAtIndex(source, index, nil) {
                        duration += TimeInterval(self.sd_frameDuration(at: index, source: source) * Float(min(interval, 3)))
                        
                        imageArr.append(UIImage(cgImage: image, scale: UIScreen.main.scale, orientation: .up))
                    }
                }
                
                if duration == 0 {
                    duration = TimeInterval(1/10 * count)
                }
                
                animatedImage = UIImage.animatedImage(with: imageArr, duration: duration)
            }
        }
        
        return animatedImage
    }
    
    static func sd_frameDuration(at index: Int, source: CGImageSource) -> Float {
        var frameDuration: Float = 0.1
        if let cfFrameProperties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) {
            if let frameProperties = cfFrameProperties as? [String: AnyObject],
                let gifProperties = frameProperties[kCGImagePropertyGIFDictionary as String] as? [String: AnyObject] {
                if let delayTimeUnclampedProp = gifProperties[kCGImagePropertyGIFUnclampedDelayTime as String] as? NSNumber {
                    frameDuration = Float(truncating: delayTimeUnclampedProp)
                } else if let delayTimeProp = gifProperties[kCGImagePropertyGIFDelayTime as String] as? NSNumber {
                    frameDuration = Float(truncating: delayTimeProp)
                }
            }
        }
        frameDuration = frameDuration<0.011 ? 0.1:frameDuration
        return frameDuration
    }
}
