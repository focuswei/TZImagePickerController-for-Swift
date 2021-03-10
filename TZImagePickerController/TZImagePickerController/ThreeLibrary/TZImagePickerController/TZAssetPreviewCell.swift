//
//  TZAssetPreviewCell.swift
//  TZImagePickerController
//
//  Created by FocusWei on 2019/11/12.
//  Copyright © 2019 FocusWei. All rights reserved.
//

import UIKit
import MediaPlayer
import Photos

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
        
        contentView.addSubview(self.previewView!)
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
    var iCloudErrorIcon: UIImageView?
    var iCloudErrorLabel: UILabel?
    var iCloudSyncFailedHandle: ((_ asset: PHAsset, _ isSyncFailed: Bool) -> Void)?
    override var model: TZAssetModel? {
        didSet {
            self.configMoviePlayer()
        }
    }
    
    var videoURL: URL? {
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
        iCloudErrorIcon = UIImageView()
        iCloudErrorIcon?.image = UIImage.tz_imageNamedFromMyBundle(name: "iCloudError")
        iCloudErrorIcon?.isHidden = true
        iCloudErrorLabel = UILabel()
        iCloudErrorLabel?.font = UIFont.systemFont(ofSize: 10)
        iCloudErrorLabel?.textColor = UIColor.white
        iCloudErrorLabel?.text = Bundle.tz_localizedString(for: "iCloud sync failed")
        iCloudErrorLabel?.isHidden = true
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
                
                let error = omfp?[PHImageErrorKey] as? NSError
                let iCloudSyncFailed: Bool = TZCommonTools.isICloudSync(error: error)
                self?.iCloudErrorLabel?.isHidden = !iCloudSyncFailed
                self?.iCloudErrorIcon?.isHidden = !iCloudSyncFailed
                self?.iCloudSyncFailedHandle?(asset, iCloudSyncFailed)
                self?.cover = photo
            }
            
            TZImageManager.manager.getVideo(with: asset) { [weak self] (playerItem, info) in
                DispatchQueue.main.async {
                    if let strongSelf = self,
                       let item = playerItem {
                        strongSelf.configPlayer(with: item)
                    }
                }
            }
        } else {
            if let url = self.videoURL {
                let playerItem = AVPlayerItem.init(url: url)
                configPlayer(with: playerItem)
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
        contentView.addSubview(playButton!)
        if iCloudErrorIcon != nil {
            contentView.addSubview(iCloudErrorIcon!)
        }
        if iCloudErrorLabel != nil {
            contentView.addSubview(iCloudErrorLabel!)
        }
    }
    
    func configPlayer(with playerItem: AVPlayerItem) {
        self.player = AVPlayer.init(playerItem: playerItem)
        self.playerLayer = AVPlayerLayer.init(player: self.player)
        self.playerLayer?.backgroundColor = UIColor.black.cgColor
        self.playerLayer?.frame = self.bounds
        if let layer = self.playerLayer {
            contentView.layer.addSublayer(layer)
        }
        self.configPlayButton()
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.pausePlayerAndShowNaviBar), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: self.player?.currentItem)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer?.frame = self.bounds
        playButton?.frame = CGRect(x: 0, y: 64, width: self.tz_width, height: self.tz_height - 64 - 44)
        iCloudErrorIcon?.frame = CGRect(x: 20, y: TZCommonTools.tz_statusBarHeight() + 44 + 10, width: 28, height: 28);
        iCloudErrorLabel?.frame = CGRect(x: 53, y: TZCommonTools.tz_statusBarHeight() + 44 + 10, width: self.tz_width - 63, height: 28)
    }
    
    func photoPreviewCollectionViewDidScroll() {
        self.pausePlayerAndShowNaviBar()
    }
    
    func playButtonClick() {
        
        let currentTime: CMTime = player?.currentItem?.currentTime() ?? CMTime()
        let durationTime: CMTime = player?.currentItem?.duration ?? CMTime()
        if player?.rate == 0.0 {
            NotificationCenter.default.post(name: NSNotification.Name.init("TZ_VIDEO_PLAY_NOTIFICATION"), object: player)
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
        contentView.addSubview(previewView)
    }
    
    override init(frame: CGRect) {
        previewView = TZPhotoPreviewView.init(frame: CGRect.zero)
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
}



