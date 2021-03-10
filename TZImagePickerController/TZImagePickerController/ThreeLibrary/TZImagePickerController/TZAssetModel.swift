//
//  TZAssetModel.swift
//  TZImagePickerController
//
//  Created by FocusWei on 2019/11/12.
//  Copyright © 2019 FocusWei. All rights reserved.
//

import Foundation
import Photos

enum TZAssetModelMediaType: UInt {
    case TZAssetModelMediaTypePhoto = 0
    case TZAssetModelMediaTypeLivePhoto
    case TZAssetModelMediaTypePhotoGif
    case TZAssetModelMediaTypeVideo
    case TZAssetModelMediaTypeAudio
}

class TZAssetModel: NSObject {
    var asset: PHAsset
    var isSelected: Bool = false
    
    var type: TZAssetModelMediaType
    var timeLength: String?
    var iCloudFailed: Bool = false
    
    init(asset: PHAsset, type: TZAssetModelMediaType, timeLength: String?) {
        self.timeLength = timeLength
        self.type = type
        self.asset = asset
    }
    
    convenience init(asset: PHAsset, type: TZAssetModelMediaType) {
        self.init(asset: asset,type: type,timeLength: nil)
    }
    
    static func == (lhs: TZAssetModel, rhs: TZAssetModel) -> Bool {
        if lhs.asset != rhs.asset {
            return false
        }
        if lhs.type != rhs.type {
            return false
        }
        return true
    }
}

class TZAlbumModel: NSObject {
    
    var name: String = ""
    var count: Int = 0
    var result: PHFetchResult<PHAsset>
    var collection: PHAssetCollection?
    var options: PHFetchOptions?
    
    var models: [TZAssetModel]?
    var selectedModels: Array<TZAssetModel> = [] {
        didSet {
            if models != nil {
                self.checkSelectedModels()
            }
        }
    }
    var selectedCount: UInt = 0
    
    var isCameraRoll: Bool = false
    
    func setFetchResult(result: PHFetchResult<PHAsset>, needFetchAssets:Bool) {
        self.result = result
        if needFetchAssets {
            TZImageManager.manager.getAssets(from: result) { [weak self] (models) in
                self?.models = models
                if self?.selectedModels.isEmpty == false {
                    self?.checkSelectedModels()
                }
            }
        }
    }
    
    
    init(with phresult: PHFetchResult<PHAsset>, name: String, isCameraRoll: Bool, needFetchAssets: Bool) {
        result = phresult
        super.init()
        self.setFetchResult(result: phresult, needFetchAssets: needFetchAssets)
        self.name = name
        self.count = phresult.count
        self.isCameraRoll = isCameraRoll
        self.count = result.count
    }
    
    func checkSelectedModels() {
        self.selectedCount = 0
        var selectedAssets: Array<PHAsset> = []
        self.selectedModels.map({
            selectedAssets.append($0.asset)
        })
        
        self.models?.compactMap({ (model) in
            if selectedAssets.contains(where: { (asset) -> Bool in
                asset.localIdentifier == model.asset.localIdentifier
            }) {
                self.selectedCount += 1
            }
        })
    }
    
    func refreshFetchResult() {
        if let collection = self.collection,
           let options = self.options {
            let fetchResult = PHAsset.fetchAssets(in: collection, options: options)
            self.count = fetchResult.count
            result = fetchResult
        }
    }
}
