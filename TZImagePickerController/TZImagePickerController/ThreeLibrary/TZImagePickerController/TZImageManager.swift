//
//  TZImageManager.swift
//  TZImagePickerController
//
//  Created by FocusWei on 2019/11/19.
//  Copyright © 2019 FocusWei. All rights reserved.
//

import UIKit
import Photos
import AVFoundation

final class TZImageManager: NSObject,TZImagePickerControllerDelegate  {
    weak var pickerDelegate: TZImagePickerControllerDelegate?
    static let manager = TZImageManager()
    
    var shouldFixOrientation: Bool = false
    
    var isPreviewNetworkImage: Bool = false
    /// 默认600像素宽
    var photoPreviewMaxWidth: CGFloat = 600
    /// 默认828像素宽
    var photoWidth: CGFloat = 828 {
        didSet {
            TZScreenWidth = self.photoWidth/2
        }
    }
    /// 默认四列
    var columnNumber: Int = 4 {
        didSet {
            self.configTZScreenWidth()
            let margin: CGFloat = 4
            let viewWidth: CGFloat = (TZScreenWidth - 2*margin - 4)
            let itemWH: CGFloat = viewWidth / CGFloat(columnNumber) - margin
            self.AssetGridThumbnailSize = CGSize(width: itemWH * TZScreenScale, height: itemWH * TZScreenScale)
        }
    }
    
    /// 对照片排序，按修改时间升序，默认是YES。如果设置为NO,最新的照片会显示在最前面，内部的拍照按钮会排在第一个
    var sortAscendingByModificationDate: Bool = true

    var minPhotoWidthSelectable: CGFloat = 0
    var minPhotoHeightSelectable: CGFloat = 0
    var hideWhenCanNotSelect: Bool = false
    
    private var TZScreenWidth: CGFloat = UIScreen.main.bounds.size.width
    private var AssetGridThumbnailSize: CGSize = .zero
    private var TZScreenScale: CGFloat = 2.0
    
    /// Default is YES, if set NO, user can't picking video.
    /// 默认为YES，如果设置为NO,用户将不能选择视频
    public var allowPickingVideo: Bool = true
    /// 默认为YES，如果设置为NO,用户将不能选择发送图片
    public var allowPickingImage: Bool = true
    
    private override init() {
        super.init()
        self.configTZScreenWidth()
    }
    
    /// Return YES if Authorized 返回YES如果得到了授权
    func authorizationStatusAuthorized() -> Bool {
        if self.isPreviewNetworkImage {
            return true
        }
        let status = PHPhotoLibrary.authorizationStatus()
        if status == .notDetermined {
            self.requestAuthorizationWithCompletion(callback: nil)
        }
        return status == .authorized
    }
    
    /// check PHAuthorizationStatusLimited
    func authorizationStatusIsLimited() -> Bool {
        if #available(iOS 14.0, *) {
            let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            return status == .limited
        }
        return false
    }
    
    func requestAuthorizationWithCompletion(callback: (() -> Void)?) {
        
        let callCompletionBlock = {
            DispatchQueue.main.async {
                callback?()
            }
        }
        DispatchQueue.global().async {
            PHPhotoLibrary.requestAuthorization({ (status) in
                callCompletionBlock()
            })
        }
    }
    
    /// Get Album 获得相册/相册数组
    func getCameraRollAlbum(allowPickingVideo: Bool, allowPickingImage: Bool, needFetchAssets: Bool, callback:((_ model: TZAlbumModel) -> Void)?) {

        let option = self.configurePHFetchOptions(allowPickingVideo: allowPickingVideo, allowPickingImage: allowPickingImage)
        
        let smartAlbums: PHFetchResult = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .albumRegular, options: nil)
        smartAlbums.enumerateObjects { (collection, index, stop) in
            if collection.estimatedAssetCount <= 0 { return }
            if self.isCameraRollAlbum(metadata: collection) {
                let fetchResult = PHAsset.fetchAssets(in: collection, options: option)
                let model = TZAlbumModel.init(with: fetchResult, name: collection.localizedTitle ?? "", isCameraRoll: true, needFetchAssets: needFetchAssets, collection: collection, options: option)
                callback?(model)
                stop.pointee = true
            }
        }
        
    }
    
    func getAllAlbums(allowPickingVideo: Bool, allowPickingImage: Bool, needFetchAssets: Bool, callback:((_ modelArray: Array<TZAlbumModel>) -> Void)?) {
        var albumArr: Array<TZAlbumModel> = []
        let option = self.configurePHFetchOptions(allowPickingVideo: allowPickingVideo, allowPickingImage: allowPickingImage)
        
        let myPhotoStreamAlbum: PHFetchResult = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumMyPhotoStream, options: nil)
        let smartAlbums: PHFetchResult = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .albumRegular, options: nil)
        let syncedAlbums: PHFetchResult = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumSyncedAlbum, options: nil)
        let sharedAlbums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumCloudShared, options: nil)
        let otherAppOp = PHFetchOptions()
        otherAppOp.includeAssetSourceTypes = .typeUserLibrary
        let otherAppAlbums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: otherAppOp)
        let allAlbums: Array<PHFetchResult<PHAssetCollection>> = [myPhotoStreamAlbum,smartAlbums, syncedAlbums, sharedAlbums,otherAppAlbums]

        allAlbums.map({ albums in
            albums.enumerateObjects { (collection, index, stop) in
                if collection.estimatedAssetCount > 0 || self.isCameraRollAlbum(metadata: collection) == true {
                    let fetchResult = PHAsset.fetchAssets(in: collection, options: option)
                    
                    
                    if fetchResult.count < 1 {
                        return
                    }
                    
                    if self.pickerDelegate?.responds(to: #selector(self.pickerDelegate?.isAlbumCanSelect(albumName:result:))) == true {
                        if self.pickerDelegate?.isAlbumCanSelect?(albumName: collection.localizedTitle ?? "", result: fetchResult) == false {
                            return
                        }
                    }
                    
                    if collection.localizedTitle?.contains(Bundle.tz_localizedString(for: "Hidden")) == true {
                        return
                    }
                    if collection.localizedTitle?.contains(Bundle.tz_localizedString(for: "Deleted")) == true {
                        return
                    }
                    
                    let model = TZAlbumModel.init(with: fetchResult, name: collection.localizedTitle ?? "", isCameraRoll: self.isCameraRollAlbum(metadata: collection), needFetchAssets: needFetchAssets, collection: collection, options: option)
                    if collection.assetCollectionSubtype == .smartAlbumUserLibrary {
                        albumArr.insert(model, at: 0)
                    } else {
                        albumArr.append(model)
                    }
                    
                }
            }
            
            callback?(albumArr)
        })
        
    }
    
    func getAssets(from fetchResult: PHFetchResult<PHAsset>, callback: ((_ modelArray: Array<TZAssetModel>) -> Void)?) {
        let config: TZImagePickerConfig = TZImagePickerConfig.sharedInstance
        return self.getAssets(from: fetchResult, allowPickingVideo: config.allowPickingVideo, allowPickingImage: config.allowPickingImage, callback: callback)
    }
    
    func getAssets(from fetchResult: PHFetchResult<PHAsset>, allowPickingVideo: Bool, allowPickingImage: Bool, callback:((_ modelArray: Array<TZAssetModel>) -> Void)?) {
        var photoArray :Array<TZAssetModel> = []
        fetchResult.enumerateObjects { (asset, index, stop) in
            if let model = self.getAssetModel(with: asset, allowPickingVideo: allowPickingVideo, allowPickingImage: allowPickingImage) {
                photoArray.append(model)
            }
        }
        callback?(photoArray)
    }
    
    public func asset(modelWithAsset asset: PHAsset, allowPickingVideo: Bool, allowPickingImage: Bool) -> TZAssetModel? {
        //TODO: 过滤照片
        var canSelect = true
        if (self.pickerDelegate?.responds(to: #selector(self.pickerDelegate?.isAssetCanSelect(asset:)))) == true {
            canSelect = (self.pickerDelegate?.isAssetCanSelect!(asset: asset))!
        }
        if !canSelect {
            return nil
        }

        let type = self.getAssetType(asset: asset)

        if (!allowPickingVideo && type == .TZAssetModelMediaTypeVideo) { return nil }
        if (!allowPickingImage && type == .TZAssetModelMediaTypePhoto) { return nil }
        if (!allowPickingImage && type == .TZAssetModelMediaTypePhotoGif) { return nil }


        if self.hideWhenCanNotSelect {
            if !self.isPhotoSelectable(with: asset) {
                return nil
            }
        }
        var timelength = type == .TZAssetModelMediaTypeVideo ? "\(asset.duration)" : "0"
        timelength = self.getNewTimeFromDurationSecond(duration: (timelength as NSString).integerValue)
        let model = TZAssetModel(asset: asset, type: type, timeLength: timelength)
        return model
    }
    
    func getAssetFromFetchResult(result: PHFetchResult<PHAsset>,at index: Int, allowPickingVideo: Bool, allowPickingImage: Bool, needFetchAssets: Bool, callback:((_ model: TZAssetModel?) -> Void)?) {
        if index < result.count {
            let asset = result.object(at: index)
            let model = self.getAssetModel(with: asset, allowPickingVideo: allowPickingVideo, allowPickingImage: allowPickingImage)
            callback?(model)
        } else {
            callback?(nil)
        }
    }
    
    /// Get photo 封面图照片
    func getPostImage(with albumModel: TZAlbumModel, callback: ((_ postImage: UIImage) -> Void)?) -> PHImageRequestID? {

        if let asset = self.sortAscendingByModificationDate ?albumModel.result.lastObject:albumModel.result.firstObject {
            return TZImageManager.manager.getPhoto(with: asset, photoWidth: 80) { (image, info, isDegraded) in
                callback?(image)
            }
        }
        return nil
    }
    
    /// 获取图片实例
    @discardableResult
    func getPhoto(with asset: PHAsset, callback: ((_ photo: UIImage, _ info: Dictionary<AnyHashable,Any>?, _ isDegraded: Bool) -> Void)?) -> PHImageRequestID {
        var fullScreenWidth = TZScreenWidth
        if fullScreenWidth > photoPreviewMaxWidth {
            fullScreenWidth = photoPreviewMaxWidth
        }
        return self.getPhoto(with: asset, photoWidth: fullScreenWidth, callback: callback, progressHandler: nil, networkAccessAllowed: true)
    }
    
    @discardableResult
    func getPhoto(with asset: PHAsset, photoWidth: CGFloat, callback: ((_ photo: UIImage, _ info: Dictionary<AnyHashable,Any>?, _ isDegraded: Bool) -> Void)?) -> PHImageRequestID {
        return self.getPhoto(with: asset, photoWidth: photoWidth, callback: callback, progressHandler: nil, networkAccessAllowed: true)
    }
    @discardableResult
    func getPhoto(with asset: PHAsset, callback: ((_ photo: UIImage, _ info: Dictionary<AnyHashable,Any>?, _ isDegraded: Bool) -> Void)?, progressHandler: ((_ progress: Double, _ error: Error?, _ stop: Bool, _ info: [AnyHashable : Any]?) -> Void)?, networkAccessAllowed: Bool) -> PHImageRequestID {
        var fullScreenWidth = TZScreenWidth
        if photoPreviewMaxWidth > 0 && fullScreenWidth > photoPreviewMaxWidth {
            fullScreenWidth = photoPreviewMaxWidth
        }
        return self.getPhoto(with: asset, photoWidth: fullScreenWidth, callback: callback, progressHandler: progressHandler, networkAccessAllowed: networkAccessAllowed)
    }
    
    @discardableResult
    func getPhoto(with asset: PHAsset, photoWidth: CGFloat,callback: ((_ photo: UIImage, _ info: Dictionary<AnyHashable,Any>?, _ isDegraded: Bool) -> Void)?, progressHandler: ((_ progress: Double, _ error: Error?, _ stop: Bool, _ info: [AnyHashable : Any]?) -> Void)?, networkAccessAllowed: Bool) -> PHImageRequestID {
        var imageSize = CGSize.zero
        if photoWidth < TZScreenWidth && photoWidth < photoPreviewMaxWidth {
            imageSize = AssetGridThumbnailSize
        } else {
            let aspectRatio: CGFloat = CGFloat(asset.pixelWidth) / CGFloat(asset.pixelHeight)
            var pixelWidth: CGFloat = photoWidth * TZScreenScale
            //超宽图片
            if aspectRatio > 1.8 {
                pixelWidth = pixelWidth * aspectRatio
            }
            // 超高图片
            if aspectRatio < 0.2 {
                pixelWidth = pixelWidth * 0.5
            }
            let pixelHeight = pixelWidth / aspectRatio
            imageSize = CGSize(width: pixelWidth, height: pixelHeight)
        }
        
        let options = PHImageRequestOptions()
        options.resizeMode = .fast
        let imageRequestID = PHImageManager.default().requestImage(for: asset, targetSize: imageSize, contentMode: .aspectFill, options: options) { [weak self] (result, info) in
            
            guard let strongSelf = self else { return }
            strongSelf.checkRequestImageState(result: result, info: info, callback: callback)
            
            // Download image from iCloud / 从iCloud下载图片
            if info?[PHImageResultIsInCloudKey] != nil,
                result == nil,
                networkAccessAllowed {
                let requestOption = PHImageRequestOptions()
        
                requestOption.progressHandler = { (progress, error, stop, info) in
                    DispatchQueue.main.async {
                        progressHandler?(progress, error, stop.pointee.boolValue, info)
                    }
                }
                requestOption.isNetworkAccessAllowed = true
                requestOption.resizeMode = .fast
                PHImageManager.default().requestImageData(for: asset, options: requestOption) { (result, dataUTI, orientation, info) in
                    if let data = result,var icloudImage = UIImage.init(data: data) {
                        if TZImagePickerConfig.sharedInstance.notScaleImage == false {
                            icloudImage = strongSelf.scaleImage(icloudImage, to: imageSize)
                        }
                        icloudImage = strongSelf.fixOrientation(image: icloudImage)
                        callback?(icloudImage, info, false)
                    }
                }
            }
        }
        return imageRequestID
    }
    
    /// Get full Image 获取原图
    @discardableResult func getOriginalPhoto(with asset: PHAsset, callback: ((_ photo: UIImage, _ info: Dictionary<AnyHashable,Any>?) -> Void)?) -> PHImageRequestID {
        return self.getOriginalPhoto(with: asset) { (photo, info, isDegraded) in
            callback?(photo, info)
        }
    }
    @discardableResult func getOriginalPhoto(with asset: PHAsset, callback: ((_ photo: UIImage, _ info: Dictionary<AnyHashable,Any>?, _ isDegraded: Bool) -> Void)?) -> PHImageRequestID {
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.resizeMode = .fast
        return PHImageManager.default().requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .aspectFit, options: options) { [weak self] (result, info) in
            guard let strongSelf = self else { return }
            strongSelf.checkRequestImageState(result: result, info: info, callback: callback)
        }
    }
    @discardableResult func getOriginalPhotoData(with asset: PHAsset, callback: ((_ data: Data, _ info: Dictionary<AnyHashable,Any>?) -> Void)?) -> PHImageRequestID {
        return self.getOriginalPhotoData(with: asset, progressHandler: nil, callback: callback)
    }
    
    @discardableResult func getOriginalPhotoData(with asset: PHAsset, progressHandler: ((_ progress: Double, _ error: Error?, _ stop: Bool, _ info: Dictionary<AnyHashable,Any>?) -> Void)?, callback: ((_ data: Data, _ info: Dictionary<AnyHashable,Any>?) -> Void)?) -> PHImageRequestID {
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.progressHandler = { (progress,error,stop,info) in
            progressHandler?(progress,error,stop.pointee.boolValue,info)
        }
        if options.version == .current {
            options.deliveryMode = .highQualityFormat
        }
        return PHImageManager.default().requestImageData(for: asset, options: options) { (result, dataUTI, orientation, info) in
            if let isCancel = info?[PHImageCancelledKey] as? Bool,
                isCancel == false,
                info?[PHImageErrorKey] == nil,
                let data = result {
                callback?(data,info)
            }
        }
    }
    
    
    /// Save photo 保存照片
    func savePhoto(with image: UIImage, callback: ((_ asset: PHAsset?, _ error: Error?) -> Void)?) {
        self.savePhoto(with: image, location: nil, callback: callback)
    }
    func savePhoto(with image: UIImage, location: CLLocation?, callback: ((_ asset: PHAsset?, _ error: Error?) -> Void)?) {
        var localIdentifier: String? = nil
        PHPhotoLibrary.shared().performChanges({
            let request = PHAssetChangeRequest.creationRequestForAsset(from: image)
            localIdentifier = request.placeholderForCreatedAsset?.localIdentifier
            request.location = location
            request.creationDate = Date()
        }) { (success, error) in
            DispatchQueue.main.async {
                if success,let localId = localIdentifier {
                    let asset = PHAsset.fetchAssets(withLocalIdentifiers: [localId], options: nil).firstObject
                    callback?(asset, nil)
                } else {
                    callback?(nil, error)
                }
            }
        }
    }
    
    /// Save video 保存视频
    func saveVideo(with url: URL, callback: ((_ asset: PHAsset?, _ error: Error?) -> Void)?) {
        self.saveVideo(with: url, location: nil, callback: callback)
    }
    func saveVideo(with url: URL, location: CLLocation?, callback: ((_ asset: PHAsset?, _ error: Error?) -> Void)?) {
        var localIdentifier: String? = nil
        PHPhotoLibrary.shared().performChanges({
            let request = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            localIdentifier = request?.placeholderForCreatedAsset?.localIdentifier
            request?.location = location
            request?.creationDate = Date()
        }) { (success, error) in
            DispatchQueue.main.async {
                if success,let localId = localIdentifier {
                    let asset = PHAsset.fetchAssets(withLocalIdentifiers: [localId], options: nil).firstObject
                    callback?(asset, nil)
                }
            }
        }
    }
    
    /// Get video 获得视频
    func getVideo(with asset: PHAsset, callback: ((_ playerItem: AVPlayerItem?, _ info: Dictionary<AnyHashable,Any>?) -> Void)?) {
        self.getVideo(with: asset, progressHandler: nil, callback: callback)
    }
    func getVideo(with asset: PHAsset, progressHandler: ((_ progress: Double, _ error: Error?, _ stop: Bool, _ info: Dictionary<AnyHashable,Any>?) -> Void)?, callback: ((_ playerItem: AVPlayerItem?, _ info: Dictionary<AnyHashable,Any>?) -> Void)?) {
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.progressHandler = { (progress, error, stop, info) in
            DispatchQueue.main.async {
                progressHandler?(progress, error, stop.pointee.boolValue, info)
            }
        }
        PHImageManager.default().requestPlayerItem(forVideo: asset, options: options) { (avPlayerItem, info) in
            callback?(avPlayerItem, info)
        }
    }
    
    /// Export video 导出视频
    func getVideoOutputPath(with asset: PHAsset, success: ((_ outputPath: String) -> Void)?, failure: ((_ errorMessage: String, _ error: Error?) -> Void)?) {
        self.getVideoOutputPath(with: asset, presetName: AVAssetExportPresetMediumQuality, success: success, failure: failure)
    }
    func getVideoOutputPath(with asset: PHAsset, presetName: String, success: ((_ outputPath: String) -> Void)?, failure: ((_ errorMessage: String, _ error: Error?) -> Void)?) {
        if #available(iOS 14.0, *) {
            self.requestVideoOutputPath(with: asset, presetName: presetName, success: success, failure: failure)
            return;
        }
        let options = PHVideoRequestOptions()
        options.version = .original
        options.deliveryMode = .automatic
        options.isNetworkAccessAllowed = true
        PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { (avasset, avAudioMix, info) in
            if let videoAsset = avasset as? AVURLAsset {
                self.startExportVideo(with: videoAsset, presetName: presetName, success: success, failure: failure)
            }
        }
    }
    
    func getVideoOutputPath() -> String {
        let formater = DateFormatter()
        formater.dateFormat = "yyyy-MM-dd-HH:mm:ss-SSS"
        let outputPath: String = NSHomeDirectory().appendingFormat("/tmp/video-%@.mp4", formater.string(from: Date()))
        return outputPath
    }
    
    func requestVideoOutputPath(with asset: PHAsset, presetName: String = AVAssetExportPresetMediumQuality, success: ((_ outputPath: String) -> Void)?, failure: ((_ errorMessage: String, _ error: Error?) -> Void)?) {
        PHImageManager.default().requestExportSession(forVideo: asset, options: self.getVideoRequestOptions(), exportPreset: presetName) { [weak self] (exportSession, info) in
            let outputPath = self?.getVideoOutputPath() ?? ""
            exportSession?.outputURL = URL(fileURLWithPath: outputPath)
            exportSession?.shouldOptimizeForNetworkUse = false
            exportSession?.outputFileType = .mp4
            exportSession?.exportAsynchronously(completionHandler: (self?.handleVideoExportResult(session: exportSession, outputPath: outputPath, success: success, failure: failure))!)
        }
    }
    
    func handleVideoExportResult(session: AVAssetExportSession?, outputPath: String, success: ((_ outputPath: String) -> Void)?, failure: ((_ errorMessage: String, _ error: Error?) -> Void)?) -> (()-> Void) {
        return {
            DispatchQueue.main.async {
                switch session?.status {
                case .unknown, .waiting, .exporting:
                    break
                case .completed:
                    success?(outputPath)
                case .failed:
                    failure?("视频导出失败",session?.error)
                case .cancelled:
                    failure?("导出任务已被取消", nil)
                default:
                    break
                }
            }
        }
    }
    
    func getVideoRequestOptions() -> PHVideoRequestOptions {
        let options = PHVideoRequestOptions()
        options.version = .original
        options.deliveryMode = .automatic
        options.isNetworkAccessAllowed = true
        return options
    }
    
    /// Get photo bytes 获得一组照片的大小
    func getPhotosBytes(withArray photos: Array<TZAssetModel>, callback: ((_ totalBytes: String) -> Void)?) {
        if photos.isEmpty {
            callback?("0B")
        }
        var dataLength = 0
        var assetCount = 0
        for model in photos {
            let options = PHImageRequestOptions()
            options.resizeMode = .fast
            options.isNetworkAccessAllowed = true
            if model.type == .TZAssetModelMediaTypePhotoGif {
                options.version = .original
            }
            //MARK:请求较大的图片质量，影响效率
            PHImageManager.default().requestImageData(for: model.asset, options: options) { (imageData, dataUTI, orientation, info) in
                if model.type != .TZAssetModelMediaTypeVideo {
                    dataLength += imageData?.count ?? 0
                }
                assetCount += 1
                if assetCount >= photos.count {
                    let bytes = self.getBytes(from: dataLength)
                    callback?(bytes)
                }
            }
        }
    }
    
    func isCameraRollAlbum(metadata: PHAssetCollection) -> Bool {
        return metadata.assetCollectionSubtype == .smartAlbumUserLibrary
    }
    /// 检查照片大小是否满足最小要求
    func isPhotoSelectable(with asset: PHAsset?) -> Bool {
        guard let asset = asset else { return false }
        let photoSize = CGSize(width: asset.pixelWidth, height: asset.pixelHeight)
        if self.minPhotoWidthSelectable > photoSize.width || self.minPhotoHeightSelectable > photoSize.height {
            return false
        }
        return true
    }
    
    /// 修正图片转向
    func fixOrientation(image: UIImage) -> UIImage {
        if self.shouldFixOrientation == false { return image }
        
        if image.imageOrientation == .up { return image }
        
        var transform: CGAffineTransform = .identity
        
        switch image.imageOrientation {
        case .down,.downMirrored:
            transform = transform.translatedBy(x: image.size.width, y: image.size.height)
            transform = transform.rotated(by: CGFloat.pi)
        case .left,.leftMirrored:
            transform = transform.translatedBy(x: image.size.width, y: 0)
            transform = transform.rotated(by: CGFloat.pi/2)
        case .right,.rightMirrored:
            transform = transform.translatedBy(x: 0, y: image.size.height)
            transform = transform.rotated(by: -CGFloat.pi/2)
        default:
            break
        }
        
        switch image.imageOrientation {
        case .upMirrored,.downMirrored:
            transform = transform.translatedBy(x: image.size.width, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
        case .leftMirrored,.rightMirrored:
            transform = transform.translatedBy(x: image.size.height, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
        default:
            break
        }
        
        let ctx = CGContext.init(data: nil, width: Int(image.size.width), height: Int(image.size.height), bitsPerComponent: image.cgImage?.bitsPerComponent ?? 0, bytesPerRow: 0, space: image.cgImage?.colorSpace ?? CGColorSpaceCreateDeviceRGB(), bitmapInfo: (image.cgImage?.bitmapInfo.rawValue)!)
        
        ctx?.concatenate(transform)
        switch image.imageOrientation {
        case .left,.leftMirrored,.rightMirrored,.right:
            ctx?.draw(image.cgImage!, in: CGRect(x: 0, y: 0, width: image.size.height, height: image.size.width))
        default:
            ctx?.draw(image.cgImage!, in: CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height))
            break
        }
        
        if let cgimage = ctx?.makeImage() {
            let newImage = UIImage.init(cgImage: cgimage)
            return newImage
        }
        
        return image
    }
    /// 获取asset的资源类型
    func getAssetType(asset: PHAsset) -> TZAssetModelMediaType {
        var type: TZAssetModelMediaType = .TZAssetModelMediaTypePhoto
        switch asset.mediaType {
        case .video:
            type = .TZAssetModelMediaTypeVideo
        case .audio:
            type = .TZAssetModelMediaTypeAudio
        case .image:
            type = .TZAssetModelMediaTypePhoto
            if #available(iOS 11.0, *) {
                if asset.playbackStyle == .imageAnimated {
                    type = .TZAssetModelMediaTypePhotoGif
                }
            }
            
        default:
            break
        }
        return type
    }
    /// 缩放图片至新尺寸
    func scaleImage(_ image: UIImage, to size: CGSize) -> UIImage {
        if image.size.width > size.width {
            UIGraphicsBeginImageContext(size)
            image.draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
            let newImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            return newImage ?? image
        }
        return image
    }
    
    /// 判断asset是否是视频
    func isVideo(from asset: PHAsset?) -> Bool {
        return asset?.mediaType == .video
    }
    
    func getNewTimeFromDurationSecond(duration: Int) -> String {
        var newTime: String
        if duration < 10 {
            newTime = String(format: "0:0%zd", duration)
        } else if duration < 60 {
            newTime = String(format: "0:%zd", duration)
        } else {
            let min = duration / 60
            let sec = duration - (min*60)
            if sec < 10 {
                newTime = String(format: "%zd:0%zd",min,sec)
            } else {
                newTime = String(format: "%zd:%zd",min,sec)
            }
        }
        return newTime
    }
    
    //MARK: private function
    private func configTZScreenWidth() {
        TZScreenWidth = UIScreen.main.bounds.size.width
        TZScreenScale = 2.0
        if TZScreenWidth > 700 {
            TZScreenScale = 1.5
        }
    }
    
    private func configurePHFetchOptions(allowPickingVideo: Bool, allowPickingImage: Bool) -> PHFetchOptions {
        let option = PHFetchOptions.init()
        if allowPickingVideo == false {
            option.predicate = NSPredicate.init(format: "mediaType == %ld", PHAssetMediaType.image.rawValue)
        }
        if allowPickingImage == false {
            option.predicate = NSPredicate.init(format: "mediaType == %ld", PHAssetMediaType.video.rawValue)
        }
        
        if self.sortAscendingByModificationDate == false {
            option.sortDescriptors = [NSSortDescriptor.init(key: "creationDate", ascending: self.sortAscendingByModificationDate)]
        }
        return option
    }
    
    private func getAssetModel(with asset:PHAsset, allowPickingVideo: Bool, allowPickingImage: Bool) -> TZAssetModel? {
        
        let canSelect = self.pickerDelegate?.isAssetCanSelect?(asset: asset) ?? true
        if canSelect == false { return nil }
        let assettype = self.getAssetType(asset: asset)
        if !allowPickingVideo && assettype == .TZAssetModelMediaTypeVideo {
            return nil
        }
        if !allowPickingImage && (assettype == .TZAssetModelMediaTypePhoto || assettype == .TZAssetModelMediaTypePhotoGif) {
            return nil
        }
        
        if self.hideWhenCanNotSelect,
            self.isPhotoSelectable(with: asset) == false {
            return nil
        }
        var timeLength = assettype == .TZAssetModelMediaTypeVideo ? String(format: "%0.0f", asset.duration) : ""
        timeLength = self.getNewTimeFromDurationSecond(duration: Int(timeLength) ?? 0)
        let model = TZAssetModel(asset: asset, type: assettype, timeLength: timeLength)
        return model
    }
    
    private func getBytes(from dataLength: Int) -> String {
        var bytes: String
        if Float(dataLength) >= 0.1*(1024*1024) {
            bytes = String(format: "%0.1fM", Float(dataLength/1024)/1024.0)
        } else if dataLength >= 1024 {
            bytes = String(format: "%0.0fK", Float(dataLength)/1024.0)
        } else {
            bytes = String(format: "%zdB", dataLength)
        }
        return bytes
    }
    
    private func checkRequestImageState(result: UIImage?, info: [AnyHashable:Any]?, callback: ((_ photo: UIImage, _ info: Dictionary<AnyHashable,Any>?, _ isDegraded: Bool) -> Void)?) {
        var downloadFinined: Bool
        if info?[PHImageCancelledKey] as? Bool ?? true,
            info?[PHImageErrorKey] == nil {
            downloadFinined = true
        } else {
            downloadFinined = false
        }
        if downloadFinined && result != nil {
            let fixResult: UIImage = self.fixOrientation(image: result!)
            let emptyDic: [AnyHashable:Any] = [:]
            let IsDegraded: Bool? = info?[PHImageResultIsDegradedKey] as? Bool
            callback?(fixResult, info ?? emptyDic, IsDegraded ?? false)
        }
    }
    
    private func fixedComposition(with asset: AVAsset) -> AVMutableVideoComposition {
        let videoComposition = AVMutableVideoComposition()
        
        let degrees = self.degressFromVideoFile(with: asset)
        if degrees != 0 {
            var translateToCenter: CGAffineTransform
            var mixedTransform: CGAffineTransform
            videoComposition.frameDuration = CMTime(seconds: 1.0, preferredTimescale: 30)
            
            let tracks = asset.tracks(withMediaType: .video)
            if let videoTrack = tracks.first {
                // 顺时针旋转90°
                let roateInstruction = AVMutableVideoCompositionInstruction()
                roateInstruction.timeRange = CMTimeRange(start: CMTime.zero, duration: videoTrack.minFrameDuration)
                let roateLayerInstruction = AVMutableVideoCompositionLayerInstruction.init(assetTrack: videoTrack)
                if degrees == 90 {
                    translateToCenter = CGAffineTransform(translationX: videoTrack.naturalSize.height, y: 0.0)
                    mixedTransform = translateToCenter.rotated(by: CGFloat.pi/2)
                    videoComposition.renderSize = CGSize(width: videoTrack.naturalSize.height, height: videoTrack.naturalSize.width)
                    roateLayerInstruction.setTransform(mixedTransform, at: CMTime.zero)
                } else if degrees == 180 {
                    // 顺时针旋转180°
                    translateToCenter = CGAffineTransform(translationX: videoTrack.naturalSize.width, y: videoTrack.naturalSize.height)
                    mixedTransform = translateToCenter.rotated(by: CGFloat.pi)
                    videoComposition.renderSize = CGSize(width: videoTrack.naturalSize.width, height: videoTrack.naturalSize.height)
                    roateLayerInstruction.setTransform(mixedTransform, at: CMTime.zero)
                } else if degrees == 270 {
                    translateToCenter = CGAffineTransform(translationX: 0.0, y: videoTrack.naturalSize.width)
                    mixedTransform = translateToCenter.rotated(by: CGFloat.pi*3/2)
                    videoComposition.renderSize = CGSize(width: videoTrack.naturalSize.height, height: videoTrack.naturalSize.width)
                    roateLayerInstruction.setTransform(mixedTransform, at: CMTime.zero)
                }
                
                roateInstruction.layerInstructions = [roateLayerInstruction]
                videoComposition.instructions = [roateInstruction]
            }
            
            
        }
        
        return videoComposition
    }
    
    private func degressFromVideoFile(with asset:AVAsset) -> Int {
        var degrees: Int = 0
        let tracks = asset.tracks(withMediaType: .video)
        if tracks.count > 0 {
            let videoTrack = tracks.first
            let t = videoTrack?.preferredTransform
            if t?.a == 0 && t?.b == 1.0 && t?.c == -1.0 && t?.d == 0 {
                degrees = 90
            } else if t?.a == 0 && t?.b == -1.0 && t?.c == 1.0 && t?.d == 0 {
                degrees = 270
            } else if t?.a == 1.0 && t?.b == 0 && t?.c == 0 && t?.d == 1.0 {
                degrees = 0
            } else if t?.a == -1.0 && t?.b == 0 && t?.c == 0 && t?.d == -1.0 {
                degrees = 180
            }
        }
        return degrees
    }
    
    private func startExportVideo(with videoAsset: AVURLAsset, presetName: String, success: ((_ outputPath: String) -> Void)?, failure: ((_ errorMessage: String, _ error:Error?) -> Void)?) {
        let presets = AVAssetExportSession.exportPresets(compatibleWith: videoAsset)
        
        if presets.contains(presetName) {
            let session: AVAssetExportSession? = AVAssetExportSession(asset: videoAsset, presetName: presetName)
            let formater = DateFormatter()
            formater.dateFormat = "yyyy-MM-dd-HH:mm:ss-SSS"
            var outputPath: String = NSHomeDirectory().appendingFormat("/tmp/video-%@.mp4", formater.string(from: Date()))
            if !videoAsset.url.lastPathComponent.isEmpty {
                outputPath = outputPath.replacingOccurrences(of: ".mp4", with: String(format: "-%@", videoAsset.url.lastPathComponent))
            }
            
            session?.outputURL = URL.init(fileURLWithPath: outputPath)
            
            session?.shouldOptimizeForNetworkUse = true
            
            let supportedTypeArray = session?.supportedFileTypes
            if supportedTypeArray?.contains(.mp4) ?? false {
                session?.outputFileType = .mp4
            } else if (supportedTypeArray?.count == 0) {
                failure?("该视频类型暂不支持导出", nil)
            } else {
                session?.outputFileType = supportedTypeArray?.first
            }
            
            if !FileManager.default.fileExists(atPath: NSHomeDirectory().appending("/tmp")) {
                do {
                    try FileManager.default.createDirectory(atPath: NSHomeDirectory().appending("/tmp"), withIntermediateDirectories: true, attributes: nil)
                } catch {
                    debugPrint("error: \(error)")
                    failure?(error.localizedDescription, error)
                }
            }
            
            if TZImagePickerConfig.sharedInstance.needFixComposition {
                let videoComposition = self.fixedComposition(with: videoAsset)
                if videoComposition.renderSize.width != 0 {
                    // 修正视频转向
                    session?.videoComposition = videoComposition
                }
            }
            
            session?.exportAsynchronously(completionHandler: {
                DispatchQueue.main.async {
                    switch session?.status {
                    case .unknown, .waiting, .exporting:
                        break
                    case .completed:
                        success?(outputPath)
                    case .failed:
                        failure?("视频导出失败",session?.error)
                    case .cancelled:
                        failure?("导出任务已被取消", nil)
                    default:
                        break
                    }
                }
            })
        } else {
            failure?(String(format: "当前设备不支持该预设:%@", presetName), nil)
        }
    }
    
    deinit {
        
    }
}
