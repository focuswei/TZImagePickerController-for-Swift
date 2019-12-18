//
//  .swift
//  TZImagePickerController
//
//  Created by guozw3 on 2019/11/13.
//  Copyright © 2019 centaline. All rights reserved.
//

import UIKit
import Photos

enum TZAssetCellType: UInt {
    case TZAssetCellTypePhoto = 0
    case TZAssetCellTypeLivePhoto
    case TZAssetCellTypePhotoGif
    case TZAssetCellTypeVideo
    case TZAssetCellTypeAudio
}

class TZAssetCell: UICollectionViewCell {
    
    var model: TZAssetModel? {
        didSet {
            guard let data = self.model else { return }
            self.representedAssetIdentifier = data.asset.localIdentifier
            
            let imageRequestID: Int32 = TZImageManager.manager.getPhoto(with: data.asset, photoWidth: self.tz_width) { [weak self] (photo, info, isDegraded) in
                if self?.representedAssetIdentifier == data.asset.localIdentifier {
                    self?.imageView.image = photo
                } else {
                    PHImageManager.default().cancelImageRequest(self?.imageRequestID ?? 0)
                }
                if isDegraded == false {
                    self?.hideProgressView()
                    self?.imageRequestID = 0
                }
            }
            
            if imageRequestID > 0 && self.imageRequestID > 0 && imageRequestID != self.imageRequestID {
                PHImageManager.default().cancelImageRequest(self.imageRequestID)
            }
            self.imageRequestID = imageRequestID
            self.selectPhotoButton.isSelected = data.isSelected
            self.selectImageView.image = self.selectPhotoButton.isSelected ? self.photoSelImage:self.photoDefImage
            self.indexLabel.isHidden = !self.selectPhotoButton.isSelected
            
            self.type = TZAssetCellType(rawValue: data.type.rawValue) ?? .TZAssetCellTypePhoto
            // 让宽度/高度小于 最小可选照片尺寸 的图片不能选中
            if !TZImageManager.manager.isPhotoSelectable(with: model?.asset) {
                if selectImageView.isHighlighted == false {
                    self.selectImageView.isHidden = true
                    selectImageView.isHidden = true
                }
            }
            
            if data.isSelected {
                self.requestBigImage()
            } else {
                self.cancelBigImageRequest()
            }
            self.setNeedsLayout()
            
            self.assetCellDidSetModelClosure?(self, imageView, selectImageView, indexLabel, bottomView, timeLength, videoImgView)
        }
    }
    var index: Int = 0 {
        didSet {
            self.indexLabel.text = String(format: "%zd", self.index)
            self.contentView.bringSubviewToFront(self.indexLabel)
        }
    }
    var didSelectPhotoClosure: ((_: Bool) -> Void)?
    var type: TZAssetCellType? {
        didSet {
            if (type == .TZAssetCellTypePhoto || type == .TZAssetCellTypeLivePhoto || (type == .TZAssetCellTypePhotoGif && !self.allowPickingGif) || self.allowPickingMultipleVideo) {
                selectImageView.isHidden = false
                selectPhotoButton.isHidden = false
                bottomView.isHidden = true
            } else {
                selectImageView.isHidden = true
                selectPhotoButton.isHidden = true
            }
            
            if self.type == .TZAssetCellTypeVideo {
                self.bottomView.isHidden = false
                self.timeLength.text = self.model?.timeLength
                self.videoImgView.isHidden = false
                self.timeLength.frame.origin.x = self.videoImgView.frame.maxX
                self.timeLength.textAlignment = .right
            } else if self.type == .TZAssetCellTypePhotoGif && self.allowPickingGif {
                self.bottomView.isHidden = false
                self.timeLength.text = "GIF"
                self.videoImgView.isHidden = true
                self.timeLength.frame.origin.x = 5
                self.timeLength.textAlignment = .left
            }
        }
    }
    var allowPickingGif: Bool = false
    var allowPickingMultipleVideo: Bool = false
    var representedAssetIdentifier: String?
    var imageRequestID: Int32 = 0
    var photoSelImage: UIImage?
    var photoDefImage: UIImage?
    var showSelectBtn: Bool? {
        didSet {
            let selectable = TZImageManager.manager.isPhotoSelectable(with: model?.asset)
            if self.selectPhotoButton.isHidden == false {
                self.selectPhotoButton.isHidden = showSelectBtn == false || !selectable
            }
            if self.selectImageView.isHidden == false {
                self.selectImageView.isHidden = showSelectBtn == false || !selectable
            }
        }
    }
    var allowPreview: Bool = false {
        didSet {
            if self.allowPreview {
                self.imageView.isUserInteractionEnabled = false
                self.tapGesture?.isEnabled = false
            } else {
                self.imageView.isUserInteractionEnabled = true
                self.tapGesture?.isEnabled = true
            }
        }
    }
    
    var assetCellDidSetModelClosure: ((_ assetCell: TZAssetCell, _ imageView:UIImageView,_ selecedImageView:UIImageView, _ indexLabel: UILabel, _ bottomView: UIView, _ timeLength: UILabel, _ videoImgView: UIImageView) -> Void)?
    
    var assetCellDidLayoutSubviewsClosure: ((_ assetCell: TZAssetCell, _ imageView:UIImageView,_ selecedImageView:UIImageView, _ indexLabel: UILabel, _ bottomView: UIView, _ timeLength: UILabel, _ videoImgView: UIImageView) -> Void)?
    
    lazy var selectPhotoButton: UIButton = {
        let selectPhotoButton = UIButton.init()
        selectPhotoButton.addTarget(self, action: #selector((selectPhotoButtonClick(sender:))), for: UIControl.Event.touchUpInside)
        self.contentView.addSubview(selectPhotoButton)
        return selectPhotoButton
    }()
    lazy var cannotSelectLayerButton: UIButton = {
        let cannotSelectLayerButton = UIButton.init()
        self.contentView.addSubview(cannotSelectLayerButton)
        return cannotSelectLayerButton
    }()
    
    private lazy var imageView: UIImageView = {
        let imageView = UIImageView.init()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        self.contentView.addSubview(imageView)
        
        self.tapGesture = UITapGestureRecognizer(target: self, action: #selector((didTapImageView)))
        imageView.addGestureRecognizer(self.tapGesture!)
        return imageView
    }()
    private lazy var selectImageView: UIImageView = {
       let selectImageView = UIImageView.init()
       selectImageView.contentMode = UIView.ContentMode.center
       selectImageView.clipsToBounds = true
       self.contentView.addSubview(selectImageView)
       
       return selectImageView
    }()
    
    private lazy var indexLabel: UILabel = {
        let indexLabel = UILabel.init()
        indexLabel.font = UIFont.boldSystemFont(ofSize: 14)
        indexLabel.textColor = UIColor.white
        indexLabel.textAlignment = NSTextAlignment.center
        self.contentView.addSubview(indexLabel)
        return indexLabel
    }()
    private lazy var bottomView: UIView = {
        let bottomView = UIView.init()
        bottomView.backgroundColor = UIColor.bottomViewBgColor
        self.contentView.addSubview(bottomView)
        return bottomView
    }()
    private lazy var timeLength: UILabel = {
        let timeLength = UILabel.init()
        timeLength.font = UIFont.boldSystemFont(ofSize: 11)
        timeLength.textColor = UIColor.white
        timeLength.textAlignment = NSTextAlignment.right
        self.bottomView.addSubview(timeLength)
        return timeLength
    }()
    private var tapGesture: UITapGestureRecognizer?
    private lazy var videoImgView: UIImageView = {
        let videoImgView = UIImageView.init()
        videoImgView.image = UIImage.tz_imageNamedFromMyBundle(name:"VideoSendIcon")
        self.bottomView.addSubview(videoImgView)
        return videoImgView
    }()
    private lazy var progressView: TZProgressView = {
        let progressView = TZProgressView.init()
        progressView.isHidden = true
        return progressView
    }()
    private var bigImageRequestID: Int32?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        NotificationCenter.default.addObserver(self, selector: #selector((reload(noti:))), name: NSNotification.Name(rawValue: "TZ_PHOTO_PICKER_RELOAD_NOTIFICATION"), object: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    override func layoutSubviews() {
        super.layoutSubviews()
        self.cannotSelectLayerButton.frame = self.bounds
        if self.allowPreview == true {
            self.selectPhotoButton.frame = CGRect(x: self.tz_width - 44, y: 0, width: 44, height: 44)
        } else {
            self.selectPhotoButton.frame = self.bounds
        }
        
        self.selectImageView.frame = CGRect(x: self.tz_width - 27, y: 3, width: 24, height: 24)
        if let width = self.selectImageView.image?.size.width, width <= CGFloat(27.0) {
            selectImageView.contentMode = UIView.ContentMode.center
        } else {
            selectImageView.contentMode = UIView.ContentMode.scaleAspectFit
        }
        self.indexLabel.frame = selectImageView.frame
        self.imageView.frame = CGRect(x: 0, y: 0, width: self.tz_width, height: self.tz_height)
        
        let progressWH: CGFloat = 20.0
        let progressXY: CGFloat = (self.tz_width - progressWH) / 2
        self.progressView.frame = CGRect(x: progressXY, y: progressXY, width: progressWH, height: progressWH)
        
        self.bottomView.frame = CGRect(x: 0, y: self.tz_height - 17, width: self.tz_width, height: 17)
        self.videoImgView.frame = CGRect(x: 8, y: 0, width: 17, height: 17)
        self.timeLength.frame = CGRect(x: self.videoImgView.tz_right, y: 0, width: self.tz_width - self.videoImgView.tz_right - 5, height: 17)
        
        self.type = TZAssetCellType(rawValue: self.model?.type.rawValue ?? 0)!
        
        self.contentView.bringSubviewToFront(self.bottomView)
        self.contentView.bringSubviewToFront(self.cannotSelectLayerButton)
        self.contentView.bringSubviewToFront(self.selectPhotoButton)
        self.contentView.bringSubviewToFront(self.selectImageView)
        self.contentView.bringSubviewToFront(self.indexLabel)
    self.assetCellDidLayoutSubviewsClosure?(self,imageView,selectImageView,indexLabel,bottomView,timeLength,videoImgView)
        
    }
    
    func hideProgressView() {
        self.progressView.isHidden = true
        self.imageView.alpha = 1.0
    }
    
    func requestBigImage() {
        if let requesetId = self.bigImageRequestID {
            PHImageManager.default().cancelImageRequest(requesetId)
        }
        if let asset = model?.asset {
            bigImageRequestID = TZImageManager.manager.getPhoto(with: asset, callback: { [weak self] (photo, info, isDegraded) in
                self?.hideProgressView()
            }, progressHandler: { [weak self] (progress, error, stop, info) in
                if self?.model?.isSelected == true {
                    self?.progressView.progress = progress
                    self?.progressView.isHidden = false
                    self?.imageView.alpha = 0.4
                    if progress >= 1 {
                        self?.hideProgressView()
                    }
                } else {
                    UIApplication.shared.isNetworkActivityIndicatorVisible = false
                    self?.cancelBigImageRequest()
                }
            }, networkAccessAllowed: false)
        }
        
    }
    
    func cancelBigImageRequest() {
        if let bigImageRequestID = self.bigImageRequestID {
            PHImageManager.default().cancelImageRequest(bigImageRequestID)
        }
        self.hideProgressView()
    }
    
    @objc func selectPhotoButtonClick(sender: UIButton) -> Void {
        self.didSelectPhotoClosure?(sender.isSelected)
        self.selectImageView.image = sender.isSelected ? self.photoSelImage:self.photoDefImage
        if sender.isSelected {
            UIView.showOscillatoryAnimationWith(layer:selectImageView.layer, type:.TZOscillatoryAnimationToBigger)
            // 用户选中了该图片，提前获取一下大图
            self.requestBigImage()
        } else {
            // 取消选中，取消大图的获取
            self.cancelBigImageRequest()
        }
    }
    
    /// 只在单选状态且allowPreview为NO时会有该事件
    @objc func didTapImageView() {
        self.didSelectPhotoClosure?(false)
    }
    
    @objc func reload(noti: Notification) {
        let tzImagePickerVc: TZImagePickerController? = noti.object as? TZImagePickerController
        
        if self.model?.isSelected == true && tzImagePickerVc?.showSelectedIndex == true,
            let localIdentifier = self.model?.asset.localIdentifier {
            self.index = (tzImagePickerVc?.selectedAssetIds.index(of:localIdentifier) ?? 0) + 1
        }
        self.indexLabel.isHidden = !self.selectPhotoButton.isSelected
        
        if let tzImagePickerVc = noti.object as? TZImagePickerController,(tzImagePickerVc.selectedModels.count >= tzImagePickerVc.maxImagesCount) && tzImagePickerVc.showPhotoCannotSelectLayer == true && self.model?.isSelected == false {
            self.cannotSelectLayerButton.backgroundColor = tzImagePickerVc.cannotSelectLayerColor
            self.cannotSelectLayerButton.isHidden = false
        } else {
            self.cannotSelectLayerButton.isHidden = true
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}


class TZAssetCameraCell: UICollectionViewCell {
    var imageView: UIImageView?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = UIColor.white
        imageView = UIImageView.init()
        imageView?.backgroundColor = UIColor.init(white: 1, alpha: 0.5)
        imageView?.contentMode = .scaleAspectFill
        self.contentView.addSubview(imageView!)
        self.clipsToBounds = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        self.imageView?.frame = self.bounds
    }
}


