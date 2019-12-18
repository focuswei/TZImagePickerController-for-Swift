//
//  TZPhotoPreviewView.swift
//  TZImagePickerController
//
//  Created by guozw3 on 2019/11/12.
//  Copyright © 2019 centaline. All rights reserved.
//

import UIKit
import Photos

class TZPhotoPreviewView: UIView,UIScrollViewDelegate {
    
    private var isRequestingGIF: Bool = false
    var imageView: UIImageView?
    var scrollView: UIScrollView
    var imageContainerView: UIView
    var progressView: TZProgressView?
    var allowCrop: Bool = false {
        didSet {
            if let _asset = self.asset {
                scrollView.maximumZoomScale = allowCrop ? 4.0 : 2.5;
                let aspectRatio: CGFloat = CGFloat(_asset.pixelWidth / _asset.pixelHeight)
                // 优化超宽图片的显示
                if (aspectRatio > 1.5) {
                    self.scrollView.maximumZoomScale *= aspectRatio / 1.5;
                }
            }
        }
    }
    var cropRect: CGRect = CGRect.zero
    var scaleAspectFillCrop: Bool?
    var model: TZAssetModel? {
        didSet {
            self.isRequestingGIF = false
            scrollView.setZoomScale(1.0, animated: false)
            if self.model?.type == .TZAssetModelMediaTypePhotoGif, let asset = model?.asset {
                //先显示缩略图
                TZImageManager.manager.getPhoto(with: asset) { (photo, info, isDegraded) in
                    self.imageView?.image = photo
                    self.resizeSubviews()
                    if self.isRequestingGIF == true { return}
                    
                    self.isRequestingGIF = true
                    TZImageManager.manager.getOriginalPhotoData(with: asset, progressHandler: { (progress, error, stop, info) in
                        DispatchQueue.main.async {
                            self.progressView?.progress = progress
                            if progress >= 1 {
                                self.progressView?.isHidden = true
                            } else {
                                self.progressView?.isHidden = false
                            }
                        }
                    }) { (data, info) in
                        self.isRequestingGIF = false
                        self.progressView?.isHidden = true
                        if TZImagePickerConfig.sharedInstance.gifImagePlayClosure != nil {
                           TZImagePickerConfig.sharedInstance.gifImagePlayClosure?(self, self.imageView, data, info)
                        } else {
                            self.imageView?.image = UIImage.sd_tz_animatedGIF(with: data)
                        }
                        self.resizeSubviews()
                    }
                }
                
                
            } else {
                self.asset = self.model?.asset
            }
            
        }
    }
    
    var asset: PHAsset? {
        didSet {
            if (oldValue != nil) && (self.imageRequestID != nil) {
                PHImageManager.default().cancelImageRequest(self.imageRequestID!)
            }
            if let asset = self.asset {
                self.imageRequestID = TZImageManager.manager.getPhoto(with: asset, callback: { [weak self](photo, info, isDegraded) in
                        if asset == self?.asset {
                            self?.imageView?.image = photo
                            self?.resizeSubviews()
                            if let strongSelf = self,
                            strongSelf.imageView?.tz_height ?? 0.0  > 0.0 && self?.allowCrop == true {
                                let scale = CGFloat.maximum(strongSelf.cropRect.size.width/(strongSelf.imageView?.tz_width ?? 0.0), strongSelf.cropRect.size.height/(strongSelf.imageView?.tz_height ?? 0.0))
                                if strongSelf.scaleAspectFillCrop == true && scale > 1.0 {
                                    let multiple = strongSelf.scrollView.maximumZoomScale/strongSelf.scrollView.minimumZoomScale
                                    self?.scrollView.minimumZoomScale = scale
                                    self?.scrollView.maximumZoomScale = scale * CGFloat.maximum(multiple, 2)
                                    self?.scrollView.setZoomScale(scale, animated: true)
                                }
                            }
                            self?.progressView?.isHidden = true
                            self?.imageProgressUpdateClosure?(1)
                            if !isDegraded {
                                self?.imageRequestID = 0
                            }
                        }
                    }, progressHandler: { [weak self] (progress, error, isStop, info) in
                        DispatchQueue.main.async {
                            if asset == self?.asset {
                                self?.progressView?.isHidden = false
                                if let view = self?.progressView {
                                    self?.bringSubviewToFront(view)
                                }
                                self?.progressView?.progress = progress
                                self?.imageProgressUpdateClosure?(progress)
                                if progress >= 1 {
                                    self?.progressView?.isHidden = true
                                    self?.imageRequestID = 0
                                }
                            }
                        }
                        
                    }, networkAccessAllowed: true)
            }
                
            
            self.configMaximumZoomScale()
        }
    }
    
    var singleTapGestureClosure: (() -> Void)?
    var imageProgressUpdateClosure: ((_ progress: Double) -> Void)?
    
    var imageRequestID: Int32?
    
    override init(frame: CGRect) {
        
        scrollView = UIScrollView.init()
        scrollView.bouncesZoom = true
        scrollView.maximumZoomScale = 2.5
        scrollView.minimumZoomScale = 1.0
        scrollView.isMultipleTouchEnabled = true
        scrollView.scrollsToTop = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = true
        scrollView.autoresizingMask = UIView.AutoresizingMask(rawValue: UIView.AutoresizingMask.flexibleWidth.rawValue | UIView.AutoresizingMask.flexibleHeight.rawValue)
        
        scrollView.delaysContentTouches = false
        scrollView.canCancelContentTouches = true
        scrollView.alwaysBounceVertical = false
        if #available(iOS 11, *) {
            scrollView.contentInsetAdjustmentBehavior = UIScrollView.ContentInsetAdjustmentBehavior.never;
        }
        
        imageContainerView = UIView.init()
        imageContainerView.clipsToBounds = true
        imageContainerView.contentMode = UIView.ContentMode.scaleAspectFill
        
        imageView = UIImageView.init()
        imageView?.backgroundColor = UIColor.init(white: 1, alpha: 0.5)
        imageView?.contentMode = UIView.ContentMode.scaleAspectFill
        imageView?.clipsToBounds = true

        super.init(frame: frame)
        
        scrollView.delegate = self
        self.addSubview(scrollView)
        scrollView.addSubview(imageContainerView)
        imageContainerView.addSubview(imageView!)
        
        
        let tap1 = UITapGestureRecognizer(target: self, action: #selector(singleTap(tap:)))
        self.addGestureRecognizer(tap1)
        
        let tap2 = UITapGestureRecognizer(target: self, action: #selector(doubleTap(tap:)))
        tap2.numberOfTapsRequired = 2
        tap1.require(toFail: tap2)
        self.addGestureRecognizer(tap2)
        
        self.configProgressView()
    }
    
    func configProgressView() {
        progressView = TZProgressView.init()
        progressView!.isHidden = true
        self.addSubview(progressView!)
    }
    
    func recoverSubviews() {
        self.scrollView.setZoomScale(scrollView.minimumZoomScale, animated: false)
        self.resizeSubviews()
    }
    
    func resizeSubviews() {
        imageContainerView.tz_origin = CGPoint.zero
        imageContainerView.frame.size.width = self.scrollView.frame.width
        
        if let image = imageView?.image {
            if (image.size.height / image.size.width) > (self.tz_height / self.scrollView.tz_width) {
                imageContainerView.tz_height = floor(image.size.height / (image.size.width / self.scrollView.tz_width))
            } else {
                var height = (image.size.height / image.size.width) * self.scrollView.tz_width
                if height < 1 || height.isNaN {
                    height = self.tz_height
                }
                height = floor(height)
                imageContainerView.frame.size.height = height;
                imageContainerView.center.y = self.frame.height / 2;
            }
        }
        
        if (imageContainerView.tz_height > self.tz_height) && (imageContainerView.tz_height - self.tz_height <= 1) {
            imageContainerView.tz_height = self.tz_height
        }
        
        let contentSizeHeight: CGFloat = CGFloat.maximum(imageContainerView.tz_height, self.tz_height)
        scrollView.contentSize = CGSize.init(width: self.scrollView.tz_width, height: contentSizeHeight)
        scrollView.scrollRectToVisible(self.bounds, animated: false)
        scrollView.alwaysBounceVertical = imageContainerView.tz_height <= self.tz_height ? false:true
        imageView?.frame = imageContainerView.bounds
            
        self.refreshScrollViewContentSize()
    }
    
    func configMaximumZoomScale() {
        scrollView.maximumZoomScale = allowCrop ? 4.0:2.5
        if let phAsset = self.asset {
            let aspectRatio: CGFloat = CGFloat(phAsset.pixelWidth / phAsset.pixelHeight)
            if aspectRatio > 1.5 {
                self.scrollView.maximumZoomScale *= aspectRatio / 1.5
            }
        }
    }
    
    func refreshScrollViewContentSize() {
        /**
         允许裁剪,做如下处理
         1.让contentSize增大(裁剪框右下角的图片部分)
         2.让scrollView新增滑动区域（裁剪框左上角的图片部分）
         */
        if allowCrop {
            let contentWidthAdd: CGFloat = self.scrollView.tz_width - cropRect.maxX
            let contentHeightAdd = (CGFloat.minimum(imageContainerView.tz_height, self.tz_height) - self.cropRect.size.height) / 2
            
            let newSizeWidth = self.scrollView.contentSize.width + contentWidthAdd
            let newSizeHeight = CGFloat.maximum(self.scrollView.contentSize.height, self.tz_height) + contentHeightAdd
            scrollView.contentSize = CGSize.init(width: newSizeWidth, height: newSizeHeight)
            scrollView.alwaysBounceVertical = true
            
            if contentHeightAdd > 0 || contentWidthAdd > 0 {
                scrollView.contentInset = UIEdgeInsets.init(top: contentHeightAdd, left: cropRect.origin.x, bottom: 0, right: 0)
            } else {
                scrollView.contentInset = UIEdgeInsets.zero
            }
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        scrollView.frame = CGRect.init(x: 10, y: 0, width: self.tz_width-20, height: self.tz_height)
        let progressWH: CGFloat = 40
        let progressX = (self.tz_width - progressWH) / 2
        let progressY = (self.tz_height - progressWH) / 2
        progressView?.frame = CGRect.init(x: progressX, y: progressY, width: progressWH, height: progressWH)
        
        self.recoverSubviews()
    }
    
    //MARK: UITapGestureRecognizer Event
    @objc func singleTap(tap: UITapGestureRecognizer) -> Void {
        self.singleTapGestureClosure?()
    }
    
    @objc func doubleTap(tap: UITapGestureRecognizer) -> Void {
        if scrollView.zoomScale > scrollView.minimumZoomScale {
            scrollView.contentInset = UIEdgeInsets.zero
            scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
        } else {
            let touchPoint = tap.location(in: self.imageView)
            let newZoomScale = scrollView.maximumZoomScale
            let xSize = self.tz_width / newZoomScale
            let ySize = self.tz_height / newZoomScale
            scrollView.zoom(to: CGRect.init(x: touchPoint.x - xSize/2, y: touchPoint.y - ySize/2, width: xSize, height: ySize), animated: true)
        }
    }
    
    //MARK: UIScrollViewDelegate
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageContainerView
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        scrollView.contentInset = UIEdgeInsets.zero
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        self.refreshImageContainerViewCenter()
    }
    
    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        self.refreshScrollViewContentSize()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    //MARK: private
    private func refreshImageContainerViewCenter() {
        let offsetX = scrollView.tz_width > scrollView.contentSize.width ? ((scrollView.tz_width - scrollView.contentSize.width) * 0.5) : 0.0
        let offsetY = scrollView.tz_height > scrollView.contentSize.height ? ((scrollView.tz_height - scrollView.contentSize.height) * 0.5) : 0.0
        self.imageContainerView.center = CGPoint.init(x: scrollView.contentSize.width * 0.5 + offsetX, y: scrollView.contentSize.height * 0.5 + offsetY)
    }
}
