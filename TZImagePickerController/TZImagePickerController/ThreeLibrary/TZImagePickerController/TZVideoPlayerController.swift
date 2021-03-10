//
//  TZVideoPlayerController.swift
//  TZImagePickerController
//
//  Created by FocusWei on 2019/12/3.
//  Copyright © 2019 FocusWei. All rights reserved.
//

import UIKit
import MediaPlayer
import Photos

class TZVideoPlayerController: UIViewController {

    var model: TZAssetModel?
    
    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private var playButton: UIButton = UIButton.init(type: .custom)
    private var cover: UIImage?
    private var toolBar: UIView = UIView.init(frame: .zero)
    private var doneButton: UIButton = UIButton.init(type: .custom)
    private var progress: UIProgressView?
    private var originStatusBarStyle: UIStatusBarStyle = .default
    
    private var needShowStatusBar: Bool = TZCommonTools.isStatusBarHidden()
    
    private lazy var iCloudErrorView: UIView = {
        let _iCloudErrorView = UIView(frame: CGRect(x: 0, y: TZCommonTools.tz_statusBarHeight() + 44 + 10, width: view.tz_width, height: 28))
        let icloud: UIImageView = UIImageView.init(image: UIImage.tz_imageNamedFromMyBundle(name: "iCloudError"))
        icloud.frame = CGRect(x: 20, y: 0, width: 28, height: 28)
        _iCloudErrorView.addSubview(icloud)
        let label = UILabel.init(frame: CGRect(x: 53, y: 0, width: view.tz_width - 63, height: 28))
        label.font = UIFont.systemFont(ofSize: 10)
        label.text = Bundle.tz_localizedString(for: "iCloud sync failed")
        _iCloudErrorView.addSubview(label)
        view.addSubview(_iCloudErrorView)
        _iCloudErrorView.isHidden = true
        return _iCloudErrorView
    }()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.backgroundColor = .black
        guard let tzImagePickerVc = self.navigationController as? TZImagePickerController else { return }
        self.navigationItem.title = tzImagePickerVc.previewBtnTitleStr
        self.configMoviePlayer()
        NotificationCenter.default.addObserver(self, selector: #selector(pausePlayerAndShowNaviBar), name: UIApplication.willResignActiveNotification, object: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        originStatusBarStyle = TZCommonTools.getStatusBarStyle()
        UIApplication.shared.statusBarStyle = .lightContent
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        UIApplication.shared.statusBarStyle = originStatusBarStyle
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        let statusBarHeight = TZCommonTools.tz_statusBarHeight()
        let statusBarAndNaviBarHeight = statusBarHeight + (self.navigationController?.navigationBar.tz_height ?? 0.0)
        playerLayer?.frame = self.view.bounds
        let toolBarHeight: CGFloat = TZCommonTools.tz_safeAreaInsets().bottom + 44
        toolBar.frame = CGRect(x: 0, y: self.view.tz_height - toolBarHeight, width: self.view.tz_width, height: toolBarHeight)
        doneButton.frame = CGRect(x: self.view.tz_width-44-12, y: 0, width: 44, height: 44)
        playButton.frame = CGRect(x: 0, y: statusBarAndNaviBarHeight, width: self.view.tz_width, height: self.view.tz_height - statusBarAndNaviBarHeight - toolBarHeight)
        
        
    }
    
    func configMoviePlayer() {
        if let asset = model?.asset {
            TZImageManager.manager.getPhoto(with: asset) { [weak self] (photo, info, isDegraded) in
                let iCloudSyncFailed: Bool = TZCommonTools.isICloudSync(error: info?[PHImageErrorKey] as? NSError)
                self?.iCloudErrorView.isHidden = !iCloudSyncFailed
                if isDegraded {
                    self?.cover = photo
                    self?.doneButton.isEnabled = true
                }
            }
            
            TZImageManager.manager.getVideo(with: asset) { [weak self] (playerItem, info) in
                DispatchQueue.main.async {
                    self?.player = AVPlayer.init(playerItem: playerItem)
                    self?.playerLayer = AVPlayerLayer.init(player: self?.player)
                    self?.playerLayer?.frame = self?.view.bounds ?? .zero
                    if let strongSelf = self {
                        self?.view.layer.addSublayer(strongSelf.playerLayer!)
                        NotificationCenter.default.addObserver(strongSelf, selector: #selector(strongSelf.pausePlayerAndShowNaviBar), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: self?.player?.currentItem)
                    }
                    
                    self?.addProgressObserver()
                    self?.configPlayButton()
                    self?.configBottomToolBar()
                    
                }
            }
        }
        
    }
    
    func addProgressObserver() {
        if let playerItem = player?.currentItem {
            let progress = self.progress
            player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1.0, preferredTimescale: CMTimeScale(1.0)), queue: DispatchQueue.main) { (time) in
                let current = CMTimeGetSeconds(time)
                let total = CMTimeGetSeconds(playerItem.duration)
                if current > 0 {
                    progress?.setProgress(Float(current/total), animated: true)
                }
            }
        }
    }
    
    func configPlayButton() {
        playButton = UIButton.init(type: .custom)
        playButton.setImage(UIImage.tz_imageNamedFromMyBundle(name: "MMVideoPreviewPlay"), for: .normal)
        playButton.setImage(UIImage.tz_imageNamedFromMyBundle(name: "MMVideoPreviewPlayHL"), for: .highlighted)
        playButton.addTarget(self, action: #selector(playButtonClick), for: .touchUpInside)
        self.view.addSubview(playButton)
    }
    
    func configBottomToolBar() {
        toolBar = UIView.init(frame: .zero)
        
        toolBar.backgroundColor = UIColor.toolBarBgColor
        
        doneButton = UIButton.init(type: .custom)
        doneButton.titleLabel?.font = UIFont.systemFont(ofSize: 16.0)
        if cover == nil {
            doneButton.isEnabled = false
        }
        doneButton.addTarget(self, action: #selector(doneButtonClick), for: .touchUpInside)
        
        
        
        if let tzImagePickerVc: TZImagePickerController = self.navigationController as? TZImagePickerController {
            doneButton.setTitle(tzImagePickerVc.doneBtnTitleStr, for: .normal)
            doneButton.setTitleColor(tzImagePickerVc.oKButtonTitleColorNormal, for: .normal)
            doneButton.setTitleColor(tzImagePickerVc.oKButtonTitleColorNormal, for: .disabled)
        } else {
            doneButton.setTitle(Bundle.tz_localizedString(for: "Done"), for: .normal)
            doneButton.setTitleColor(UIColor.doneButtonTitleColor, for: .normal)
        }
        
        toolBar.addSubview(doneButton)
        self.view.addSubview(toolBar)
        
    }
    
    @objc func playButtonClick() {
        let currentTime: CMTime? = player?.currentItem?.currentTime()
        let durationTime: CMTime? = player?.currentItem?.duration
        if player?.rate == 0.0 {
            NotificationCenter.default.post(name: NSNotification.Name.init("TZ_VIDEO_PLAY_NOTIFICATION"), object: player)
            if currentTime?.value == durationTime?.value {
                player?.currentItem?.seek(to: CMTime(value: 0, timescale: 1))
            }
            player?.play()
            self.navigationController?.setNavigationBarHidden(true, animated: true)
            toolBar.isHidden = true
            playButton.setImage(nil, for: .normal)
            
        } else {
            self.pausePlayerAndShowNaviBar()
        }
    }
    
    @objc func doneButtonClick() {
        if let tzImagePickerVc: TZImagePickerController = self.navigationController as? TZImagePickerController {
            if tzImagePickerVc.autoDismiss {
                self.navigationController?.dismiss(animated: true, completion: {
                    self.callDelegateMethod()
                })
            } else {
                self.callDelegateMethod()
            }
        } else {
            self.dismiss(animated: true) {
                self.callDelegateMethod()
            }
        }
    }
    
    private func callDelegateMethod() {
        if let tzImagePickerVc: TZImagePickerController = self.navigationController as? TZImagePickerController,
            cover != nil,
            model != nil {
            
            tzImagePickerVc.pickerDelegate?.imagePickerController?(picker: tzImagePickerVc, didFinishPickingVideo: cover!, sourceAssets: model!.asset)
            
            tzImagePickerVc.didFinishPickingVideoClosure?(cover!, model!.asset)
        }
        
        
    }
    
    @objc func pausePlayerAndShowNaviBar() {
        player?.pause()
        toolBar.isHidden = false
        self.navigationController?.setNavigationBarHidden(false, animated: true)
        playButton.setImage(UIImage.tz_imageNamedFromMyBundle(name: "MMVideoPreviewPlay"), for: .normal)
        
        if self.needShowStatusBar {
            UIApplication.shared.isStatusBarHidden = false
         }
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
         if let tzImagePickerVc: TZImagePickerController = self.navigationController as? TZImagePickerController {
            return tzImagePickerVc.statusBarStyle
        }
        return super.preferredStatusBarStyle
    }
    
    init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
