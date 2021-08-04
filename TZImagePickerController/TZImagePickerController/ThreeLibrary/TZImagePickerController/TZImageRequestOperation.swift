//
//  TZImageRequestOperation.swift
//  TZImagePickerController
//
//  Created by FocusWei on 2019/12/11.
//  Copyright © 2019 FocusWei. All rights reserved.
//

import UIKit
import Photos.PHAsset

class TZImageRequestOperation: Operation {

    typealias TZImageRequestCompletedClosure = ((_ photo: UIImage, _ info: [AnyHashable:Any]?, _ isDegraded: Bool) -> Void)?
    
    typealias TZImageRequestProgressClosure = ((_ progress: Double, _ info: Error?, _ stop: Bool, _ info: [AnyHashable:Any]?) -> Void)?
    
    var completedClosure: TZImageRequestCompletedClosure
    var progressClosure: TZImageRequestProgressClosure
    
    private let lockQueue = DispatchQueue(label: "com.focuswei.async", attributes: .concurrent)
    var myIsExecuting: Bool = false
    var myIsFinished: Bool = false
    var phasset: PHAsset?
    
    override var isAsynchronous: Bool {
        return true
    }
    
    override private(set) var isExecuting: Bool {
        get {
            return lockQueue.sync { () -> Bool in
                return myIsExecuting
            }
        }

        set {
            willChangeValue(forKey: "isExecuting")
            lockQueue.sync(flags: [.barrier]) {
                myIsExecuting = newValue
            }
            didChangeValue(forKey: "isExecuting")
        }
    }
    
    override private(set) var isFinished: Bool {
        get {
            return lockQueue.sync { () -> Bool in
                return myIsFinished
            }
        }

        set {
            willChangeValue(forKey: "isFinished")
            lockQueue.sync(flags: [.barrier]) {
                myIsFinished = newValue
            }
            didChangeValue(forKey: "isFinished")
        }
    }
    
    init(with asset: PHAsset, callback: TZImageRequestCompletedClosure, progressCallback: TZImageRequestProgressClosure) {
        phasset = asset
        completedClosure = callback
        progressClosure = progressCallback
    }
    
    internal override func start() {
        
        guard !isCancelled else {
            /// 支持取消
            done()
            return
        }
        
        guard let asset = self.phasset else {
            done()
            return
        }
        
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
        self.myIsExecuting = false
        self.myIsFinished = true
        self.reset()
    }
    
    private func reset() {
        self.phasset = nil
        self.completedClosure = nil
        self.progressClosure = nil
    }
    
    deinit {
        
    }
}
