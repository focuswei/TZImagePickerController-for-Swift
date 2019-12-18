//
//  TZImageRequestOperation.swift
//  TZImagePickerController
//
//  Created by guozw3 on 2019/12/11.
//  Copyright © 2019 centaline. All rights reserved.
//

import UIKit
import Photos.PHAsset

class TZImageRequestOperation: Operation {

    typealias TZImageRequestCompletedClosure = ((_ photo: UIImage, _ info: [AnyHashable:Any]?, _ isDegraded: Bool) -> Void)?
    
    typealias TZImageRequestProgressClosure = ((_ progress: Double, _ info: Error?, _ stop: Bool, _ info: [AnyHashable:Any]?) -> Void)?
    
    var completedClosure: TZImageRequestCompletedClosure
    var myIsExecuting: Bool
    var myIsFinished: Bool
    var progressClosure: TZImageRequestProgressClosure
    var phasset: PHAsset?
    
    override var isAsynchronous: Bool {
        return true
    }
    
    override var isExecuting: Bool {
        return myIsExecuting
    }
    
    override var isFinished: Bool {
        return myIsFinished
    }
    
    init(with asset: PHAsset, callback: TZImageRequestCompletedClosure, progressCallback: TZImageRequestProgressClosure) {
        phasset = asset
        myIsExecuting = false
        myIsFinished = false
        completedClosure = callback
        progressClosure = progressCallback
        super.init()
    }
    
    internal override func start() {
        super.start()
        guard let asset = self.phasset else { return }
        
        self.myIsExecuting = true
        DispatchQueue.global().async {
            TZImageManager.manager.getPhoto(with: asset, callback: { [weak self] (photo, info, isDegraded) in
                if isDegraded == false {
                    self?.completedClosure?(photo, info, isDegraded)
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.1) {
                        self?.done()
                    }
                }
                
                }, progressHandler: { [weak self] (progress, error, stop, info) in
                    DispatchQueue.main.async {
                        self?.progressClosure?(progress, error, stop, info)
                    }
                }, networkAccessAllowed: true)
        }
        
    }
    
    
    private func done() {
        self.myIsExecuting = true
        self.myIsFinished = true
        self.reset()
        self.cancel()
    }
    
    private func reset() {
        self.phasset = nil
        self.completedClosure = nil
        self.progressClosure = nil
    }
    
    deinit {
        print("\(self) free")
    }
}
