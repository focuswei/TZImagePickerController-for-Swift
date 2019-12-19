//
//  TZAssetPreviewCell.swift
//  TZImagePickerController
//
//  Created by FocusWei on 2019/11/12.
//  Copyright © 2019 FocusWei. All rights reserved.
//

import UIKit
import MediaPlayer

class TZAssetPreviewCell: UICollectionViewCell {
    
    var model: TZAssetModel?
    var singleTapGestureClosure: (() -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.backgroundColor = UIColor.black
        self.configSubviews()
        NotificationCenter.default.addObserver(self, selector: #selector(photoPreviewCollectionViewDidScroll(notification:)), name: NSNotification.Name(rawValue: "photoPreviewCollectionViewDidScroll"), object: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configSubviews() {
        
    }
    
    @objc func photoPreviewCollectionViewDidScroll(notification: Notification) {
        
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}


class TZPhotoPreviewCell: TZAssetPreviewCell {
    var imageProgressUpdateClosure: ((_ progress: Double) -> Void)?
    var previewView: TZPhotoPreviewView?
    var allowCrop: Bool = false {
        didSet {
            previewView?.allowCrop = allowCrop
        }
    }
    var cropRect: CGRect = CGRect.zero {
        didSet {
            previewView?.cropRect = cropRect
        }
    }
    var scaleAspectFillCrop: Bool? {
        didSet {
            previewView?.scaleAspectFillCrop = scaleAspectFillCrop
        }
    }
    
    override var model: TZAssetModel? {
        didSet {
            previewView?.model = model
        }
        
    }
    
    override func configSubviews() {
        self.previewView = TZPhotoPreviewView.init(frame: .zero)
        self.previewView?.singleTapGestureClosure = { [weak self] in
            if let `self` = self {
                `self`.singleTapGestureClosure?()
            }
        }
        
        self.previewView?.imageProgressUpdateClosure = { [weak self] (progress) in
            if let `self` = self  {
                `self`.imageProgressUpdateClosure?(progress)
            }
            
        }
        
        self.addSubview(self.previewView!)
    }
    
    func recoverSubviews() {
        previewView?.recoverSubviews()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        self.previewView?.frame = self.bounds
    }
}


class TZVideoPreviewCell: TZAssetPreviewCell {
    var player: AVPlayer?
    var playerLayer: AVPlayerLayer?
    var playButton: UIButton?
    var cover: UIImage?
    override var model: TZAssetModel? {
        didSet {
            self.configMoviePlayer()
        }
    }
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func pausePlayerAndShowNaviBar() {
        if player?.rate != 0.0 {
            player?.pause()
            playButton?.setImage(UIImage.tz_imageNamedFromMyBundle(name: "MMVideoPreviewPlay"), for: .normal)
            self.singleTapGestureClosure?()
        }
    }
    
    override func configSubviews() {
        NotificationCenter.default.addObserver(self, selector: #selector(pausePlayerAndShowNaviBar), name: UIApplication.willResignActiveNotification, object: nil)
    }
    
    func configMoviePlayer() {
        if player != nil {
            playerLayer?.removeFromSuperlayer()
            playerLayer = AVPlayerLayer()
            player?.pause()
            player = nil
        }
        
        if let asset = self.model?.asset {
            TZImageManager.manager.getPhoto(with: asset) { [weak self] (photo, omfp, isDegraded) in
                self?.cover = photo
            }
            
            TZImageManager.manager.getVideo(with: asset) { [weak self] (playerItem, info) in
                DispatchQueue.main.async {
                    if let strongSelf = self {
                        strongSelf.player = AVPlayer.init(playerItem: playerItem)
                        strongSelf.playerLayer = AVPlayerLayer.init(player: strongSelf.player)
                        strongSelf.playerLayer?.backgroundColor = UIColor.black.cgColor
                        strongSelf.playerLayer?.frame = self?.bounds ?? CGRect.zero
                        if let layer = self?.playerLayer {
                            strongSelf.layer.addSublayer(layer)
                        }
                        strongSelf.configPlayButton()
                        
                        NotificationCenter.default.addObserver(strongSelf, selector: #selector(self?.pausePlayerAndShowNaviBar), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: self?.player?.currentItem)
                    }
                    
                }
            }
        }
        
    }
    
    func configPlayButton() {
        if playButton != nil {
            playButton?.removeFromSuperview()
        }
        playButton = UIButton.init(type: .custom)
        playButton?.setImage(UIImage.tz_imageNamedFromMyBundle(name: "MMVideoPreviewPlay"), for: .normal)
        playButton?.setImage(UIImage.tz_imageNamedFromMyBundle(name: "MMVideoPreviewPlayHL"), for: .highlighted)
        self.addSubview(playButton!)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer?.frame = self.bounds
        playButton?.frame = CGRect(x: 0, y: 64, width: self.tz_width, height: self.tz_height - 64 - 44)
    }
    
    func photoPreviewCollectionViewDidScroll() {
        self.pausePlayerAndShowNaviBar()
    }
    
    func playButtonClick() {
        
        let currentTime: CMTime = player?.currentItem?.currentTime() ?? CMTime()
        let durationTime: CMTime = player?.currentItem?.duration ?? CMTime()
        if player?.rate == 0.0 {
            if currentTime.value == durationTime.value {
                player?.currentItem?.seek(to: CMTime(value: 0, timescale: 1), completionHandler: nil)
            }
            player?.play()
            playButton?.setImage(nil, for: .normal)
           
            NotificationCenter.default.post(name: Notification.Name.init(rawValue: "statusBarHidden"), object: true)
            self.singleTapGestureClosure?()
        } else {
            self.pausePlayerAndShowNaviBar()
        }
        
    }
    
}

class TZGifPreviewCell: TZAssetPreviewCell {
    var previewView: TZPhotoPreviewView
    override var model: TZAssetModel? {
        didSet {
            previewView.model = self.model
        }
    }
    
    override func configSubviews() {
        self.configPreviewView()
    }
    
    func configPreviewView() {
        previewView = TZPhotoPreviewView.init(frame: CGRect.zero)
        previewView.singleTapGestureClosure = { [weak self] in
            self?.singleTapGestureClosure?()
        }
        self.addSubview(previewView)
    }
    
    override init(frame: CGRect) {
        previewView = TZPhotoPreviewView.init(frame: CGRect.zero)
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
}



