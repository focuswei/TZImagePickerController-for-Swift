//
//  TZPhotoPickerController.swift
//  TZImagePickerController
//
//  Created by guozw3 on 2019/11/26.
//  Copyright © 2019 centaline. All rights reserved.
//

import UIKit
import CoreLocation
import Photos
import MobileCoreServices

class TZPhotoPickerController: UIViewController, UICollectionViewDataSource,UICollectionViewDelegate,UIImagePickerControllerDelegate,UINavigationControllerDelegate {

    var isFirstAppear: Bool = false
    var columnNumber: Int = 0
    var model: TZAlbumModel?
    
    private var _models: Array<TZAssetModel> = []
    private var _bottomToolBar: UIView = UIView.init(frame: .zero)
    private var _previewButton: UIButton = UIButton.init(type: .custom)
    private var _doneButton: UIButton = UIButton.init(type: .custom)
    private var _numberImageView: UIImageView? = UIImageView.init()
    private var _numberLabel: UILabel? = UILabel.init()
    private var _originalPhotoButton: UIButton = UIButton.init(type: .custom)
    private var _originalPhotoLabel: UILabel = UILabel.init()
    private var _divideLine: UIView = UIView.init(frame: .zero)
    
    private var _shouldScrollToBottom: Bool  = true
    private var _showTakePhotoBtn: Bool = true
    
    private var _offsetItemCount: CGFloat = 0.0
    
    private var previousPreheatRect: CGRect = .zero
    private var isSelectOriginalPhoto: Bool = false
    private var collectionView: TZCollectionView?
    private var noDataLabel: UILabel?
    private var layout: UICollectionViewFlowLayout = UICollectionViewFlowLayout.init()
    lazy private var imagePickerVc: UIImagePickerController = {
        let imagePickerVc = UIImagePickerController.init()
        imagePickerVc.delegate = self
        // set appearance / 改变相册选择页的导航栏外观
        imagePickerVc.navigationBar.barTintColor = self.navigationController?.navigationBar.barTintColor
        imagePickerVc.navigationBar.tintColor = self.navigationController?.navigationBar.tintColor
        let tzBarItem = UIBarButtonItem.appearance(whenContainedInInstancesOf: [TZImagePickerController.self])
        let barItem = UIBarButtonItem.appearance(whenContainedInInstancesOf: [UIImagePickerController.self])
        
        barItem.setTitleTextAttributes(tzBarItem.titleTextAttributes(for: .normal), for: .normal)
        return imagePickerVc
    }()
    
    private var location: CLLocation?
    private var locationManager: TZLocationManager = {
        let locationManager = TZLocationManager.init()
        return locationManager
    }()
    
    //多线程操作
    private var operationQueue: OperationQueue
    private lazy var dispatchGroup: DispatchGroup = {
        let dispatchGroup = DispatchGroup.init()
        return dispatchGroup
    }()
    
    private var AssetGridThumbnailSize: CGSize = .zero
    private var itemMargin: CGFloat = 5
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let scale: CGFloat = UIScreen.main.bounds.size.width>600 ? 1.0:2.0
        if let layout = collectionView?.collectionViewLayout as? (UICollectionViewFlowLayout) {
            AssetGridThumbnailSize = CGSize(width: layout.itemSize.width, height: layout.itemSize.height * scale)
        }
        
        if _models.isEmpty {
            self.fetchAssetModels()
        }
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        DispatchQueue.main.async {
            
            guard let tzImagePickerVc = self.navigationController as? TZImagePickerController else { return }
            tzImagePickerVc.isSelectOriginalPhoto = self.isSelectOriginalPhoto
        }
        
        
    }
    override func viewDidLoad() {
        super.viewDidLoad()

        self.isFirstAppear = true
        _shouldScrollToBottom = true
        
        self.view.backgroundColor = .white
        self.navigationItem.title = model?.name
        
        guard let tzImagePickerVc = self.navigationController as? TZImagePickerController else { return }
        isSelectOriginalPhoto = tzImagePickerVc.isSelectOriginalPhoto

        let cancelButton = UIBarButtonItem.init(title: tzImagePickerVc.cancelBtnTitleStr, style: .plain, target: tzImagePickerVc, action: #selector(tzImagePickerVc.cancelButtonClick))
        TZCommonTools.configBarButtonItem(cancelButton, tzImagePickerVc)
        self.navigationItem.rightBarButtonItem = cancelButton
        
        if tzImagePickerVc.navLeftBarButtonSettingClosure != nil {
            let leftButton = UIButton.init(type: .custom)
            leftButton.frame = CGRect(x: 0, y: 0, width: 44, height: 44)
            leftButton.addTarget(self, action: #selector(navLeftBarButtonClick), for: .touchUpInside)
            tzImagePickerVc.navLeftBarButtonSettingClosure?(leftButton)
            self.navigationItem.leftBarButtonItem = UIBarButtonItem.init(customView: leftButton)
        } else if tzImagePickerVc.children.count > 0 {
            
            let backButton = UIBarButtonItem.init(title: Bundle.tz_localizedString(for: "Back"), style: .plain, target: nil, action: nil)
            TZCommonTools.configBarButtonItem(backButton, tzImagePickerVc)
            tzImagePickerVc.children.first?.navigationItem.backBarButtonItem = backButton
        }
        
        _showTakePhotoBtn = model?.isCameraRoll == true && ((tzImagePickerVc.allowTakePicture && tzImagePickerVc.allowPickingImage) || (tzImagePickerVc.allowTakeVideo && tzImagePickerVc.allowPickingVideo))
        
        
        NotificationCenter.default.addObserver(self, selector: #selector(didChangeStatusBarOrientationNotification(noti:)), name: UIApplication.didChangeStatusBarOrientationNotification, object: nil)
        
        
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        guard let tzImagePickerVc = self.navigationController as? TZImagePickerController else { return }
        var top: CGFloat = 0
        var collectionViewHeight: CGFloat = 0
        let naviBarHeight: CGFloat = self.navigationController?.navigationBar.tz_height ?? 0
        
        let isStatusBarHidden: Bool = TZCommonTools.isStatusBarHidden()
        let toolBarHeight: CGFloat = TZCommonTools.tz_isIPhoneX() ? 50+(83-49):50
        if self.navigationController?.navigationBar.isTranslucent == true {
            top = naviBarHeight
            if (!isStatusBarHidden) {
                top += TZCommonTools.tz_statusBarHeight()
            }
            collectionViewHeight = tzImagePickerVc.showSelectBtn ? (self.view.tz_height - toolBarHeight - top) : (self.view.tz_height - top)
        } else {
            collectionViewHeight = tzImagePickerVc.showSelectBtn ? self.view.tz_height - toolBarHeight : self.view.tz_height
        }
        
        collectionView?.frame = CGRect(x: 0, y: top, width: self.view.tz_width, height: collectionViewHeight)
        noDataLabel?.frame = collectionView?.bounds ?? .zero
        let itemWH: CGFloat = (self.view.tz_width - CGFloat(self.columnNumber + 1) * itemMargin) / CGFloat(self.columnNumber)
        layout.itemSize = CGSize(width: itemWH, height: itemWH)
        layout.minimumInteritemSpacing = itemMargin
        layout.minimumLineSpacing = itemMargin
        collectionView?.setCollectionViewLayout(layout, animated: false)
        if _offsetItemCount > 0 {
            let offsetY: CGFloat = _offsetItemCount*(layout.itemSize.height+layout.minimumInteritemSpacing)
            collectionView?.setContentOffset(CGPoint(x: 0, y: offsetY), animated: true)
        }
        
        var toolBarTop: CGFloat = 0
        if self.navigationController?.navigationBar.isHidden == false {
            toolBarTop = self.view.tz_height - toolBarHeight
        } else {
            let navigationHeight: CGFloat = naviBarHeight + TZCommonTools.tz_statusBarHeight()
            toolBarTop = self.view.tz_height - toolBarHeight - navigationHeight
        }
        _bottomToolBar.frame = CGRect(x: 0, y: toolBarTop, width: self.view.tz_width, height: toolBarHeight)
        
        var previewWidth: CGFloat = tzImagePickerVc.previewBtnTitleStr.boundingRect(with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude), options: NSStringDrawingOptions.usesFontLeading, attributes: [NSAttributedString.Key.font:UIFont.systemFont(ofSize: 16)], context: nil).width + 2
        
        if tzImagePickerVc.allowPreview == false {
            previewWidth = 0.0
        }
        _previewButton.frame = CGRect(x: 10, y: 3, width: previewWidth, height: 44)
        _previewButton.tz_width = !tzImagePickerVc.showSelectBtn ? 0:previewWidth
        if tzImagePickerVc.allowPickingOriginalPhoto {
            let fullImageWidth: CGFloat = tzImagePickerVc.fullImageBtnTitleStr.boundingRect(with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude), options: NSStringDrawingOptions.usesFontLeading, attributes: [NSAttributedString.Key.font:UIFont.systemFont(ofSize: 13)], context: nil).width
            _originalPhotoButton.frame = CGRect(x: _previewButton.frame.maxX, y: 0, width: fullImageWidth+56, height: 50)
            _originalPhotoLabel.frame = CGRect(x: fullImageWidth+46, y: 0, width: 80, height: 50)
        }
        
        _doneButton.sizeToFit()
        _doneButton.frame = CGRect(x: self.view.tz_width - _doneButton.tz_width - 12, y: 0, width: _doneButton.tz_width, height: 50)
        let numberRect = CGRect(x: _doneButton.tz_left-24-5, y: 13, width: 24, height: 24)
        _numberImageView?.frame = numberRect
        _numberLabel?.frame = numberRect
        _divideLine.frame = CGRect(x: 0, y: 0, width: self.view.tz_width, height: 1)
        
        TZImageManager.manager.columnNumber = TZImageManager.manager.columnNumber
        self.collectionView?.reloadData()
        
    }
    
    func initSubviews() {
        DispatchQueue.main.async {
            if let tzImagePickerVc = self.navigationController as? TZImagePickerController {
                tzImagePickerVc.hideProgressHUD()
            }
            self.checkSelectedModels()
            self.configCollectionView()
            self.collectionView?.isHidden = true
            self.configBottomToolBar()
            self.scrollCollectionViewToBottom()
        }
    }
    
    func fetchAssetModels() {
        guard let tzImagePickerVc = self.navigationController as? TZImagePickerController else { return }
        if isFirstAppear && model?.models?.isEmpty == false {
            tzImagePickerVc.showProgressHUD()
        }
        DispatchQueue.global().async {
            if tzImagePickerVc.sortAscendingByModificationDate == false && self.isFirstAppear && self.model?.isCameraRoll == true {
                TZImageManager.manager.getCameraRollAlbum(allowPickingVideo: tzImagePickerVc.allowPickingVideo, allowPickingImage: tzImagePickerVc.allowPickingImage, needFetchAssets: true) { [weak self] (model) in
                    self?.model = model
                    self?._models = self?.model?.models ?? []
                    self?.initSubviews()
                }
            } else {
                if self._showTakePhotoBtn || self.isFirstAppear,
                    let asset = self.model?.result {
                    TZImageManager.manager.getAssets(from: asset) { [weak self] (models) in
                        self?._models = models
                        self?.initSubviews()
                    }
                    
                } else {
                    self._models = self.model?.models ?? []
                    self.initSubviews()
                }
            }
        }
    }
    
    func configBottomToolBar() {
        guard let tzImagePickerVc = self.navigationController as? TZImagePickerController else { return }
        _bottomToolBar = UIView.init(frame: .zero)
        _bottomToolBar.backgroundColor = .init(red: 253/255.0, green: 253/255.0, blue: 253/255.0, alpha: 1.0)
        _previewButton = UIButton.init(type: .custom)
        _previewButton.addTarget(self, action: #selector(previewButtonClick), for: .touchUpInside)
        _previewButton.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        _previewButton.setTitle(tzImagePickerVc.previewBtnTitleStr, for: .normal)
        _previewButton.setTitle(tzImagePickerVc.previewBtnTitleStr, for: .disabled)
        _previewButton.setTitleColor(.black, for: .normal)
        _previewButton.setTitleColor(.lightGray, for: .disabled)
        _previewButton.isEnabled = tzImagePickerVc.selectedModels.count > 0
        
        if tzImagePickerVc.allowPickingOriginalPhoto {
            _originalPhotoButton = UIButton.init(type: .custom)
            _originalPhotoButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: TZCommonTools.tz_isRightToLeftLayout() ? 10:-10, bottom: 0, right: 0)
            _originalPhotoButton.addTarget(self, action: #selector(originalPhotoButtonClick), for: .touchUpInside)
            _originalPhotoButton.titleLabel?.font = UIFont.systemFont(ofSize: 16)
            _originalPhotoButton.setTitle(tzImagePickerVc.fullImageBtnTitleStr, for: .normal)
            _originalPhotoButton.setTitle(tzImagePickerVc.fullImageBtnTitleStr, for: .selected)
            _originalPhotoButton.setImage(tzImagePickerVc.photoOriginDefImage, for: .normal)
            _originalPhotoButton.setImage(tzImagePickerVc.photoOriginSelImage, for: .selected)
            _originalPhotoButton.setTitleColor(.lightGray, for: .normal)
            _originalPhotoButton.setTitleColor(.black, for: .selected)
            _originalPhotoButton.imageView?.clipsToBounds = true
            _originalPhotoButton.imageView?.contentMode = .scaleAspectFit
            _originalPhotoButton.isSelected = isSelectOriginalPhoto
            _previewButton.isEnabled = tzImagePickerVc.selectedModels.count > 0
            
            _originalPhotoLabel = UILabel.init()
            _originalPhotoLabel.textAlignment = .left
            _originalPhotoLabel.font = UIFont.systemFont(ofSize: 16)
            _originalPhotoLabel.textColor = .black
            if isSelectOriginalPhoto {
                self.getSelectedPhotoBytes()
            }
        }
        
        _doneButton = UIButton.init(type: .custom)
        _doneButton.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        _doneButton.addTarget(self, action: #selector(doneButtonClick), for: .touchUpInside)
        _doneButton.setTitle(tzImagePickerVc.doneBtnTitleStr, for: .normal)
        _doneButton.setTitle(tzImagePickerVc.doneBtnTitleStr, for: .disabled)
        _doneButton.setTitleColor(tzImagePickerVc.oKButtonTitleColorNormal, for: .normal)
        _doneButton.setTitleColor(tzImagePickerVc.oKButtonTitleColorDisabled, for: .disabled)
        _doneButton.isEnabled = tzImagePickerVc.selectedModels.count > 0 || tzImagePickerVc.alwaysEnableDoneBtn
        
        _numberImageView = UIImageView.init(image: tzImagePickerVc.photoNumberIconImage)
        _numberImageView?.isHidden = tzImagePickerVc.selectedModels.isEmpty
        _numberImageView?.clipsToBounds = true
        _numberImageView?.contentMode = .scaleAspectFit
        
        _numberLabel = UILabel.init()
        _numberLabel?.font = UIFont.systemFont(ofSize: 15)
        _numberLabel?.textColor = .white
        _numberLabel?.textAlignment = .center
        _numberLabel?.text = String(format: "%zd", tzImagePickerVc.selectedModels.count)
        _numberLabel?.isHidden = tzImagePickerVc.selectedModels.isEmpty
        _numberLabel?.backgroundColor = .clear
        
        _divideLine = UIView.init()
        _divideLine.backgroundColor = .init(red: 222/255.0, green: 222/255.0, blue: 222/255.0, alpha: 1.0)
        
        _bottomToolBar.addSubview(_divideLine)
        _bottomToolBar.addSubview(_previewButton)
        _bottomToolBar.addSubview(_doneButton)
        _bottomToolBar.addSubview(_numberImageView!)
        _bottomToolBar.addSubview(_numberLabel!)
        _bottomToolBar.addSubview(_originalPhotoButton)
        self.view.addSubview(_bottomToolBar)
        _originalPhotoButton.addSubview(_originalPhotoLabel)
        
    }
    
    func configCollectionView() {
        collectionView = TZCollectionView.init(frame: .zero, collectionViewLayout: layout)
        collectionView?.backgroundColor = .white
        collectionView?.dataSource = self
        collectionView?.delegate = self
        collectionView?.alwaysBounceHorizontal = false
        collectionView?.contentInset = UIEdgeInsets(top: itemMargin, left: itemMargin, bottom: itemMargin, right: itemMargin)
        
        if _showTakePhotoBtn {
            collectionView?.contentSize = CGSize(width: self.view.tz_width, height: CGFloat((_models.count + self.columnNumber) / self.columnNumber) * self.view.tz_width)
        } else {
            collectionView?.contentSize = CGSize(width: self.view.tz_width, height: CGFloat((_models.count + self.columnNumber - 1) / self.columnNumber) * self.view.tz_width)
            if _models.count == 0 {
                noDataLabel = UILabel.init()
                noDataLabel?.textAlignment = .center
                noDataLabel?.text = Bundle.tz_localizedString(for: "No Photos or Videos")
                noDataLabel?.textColor = UIColor.noDataLabelTextColor
                noDataLabel?.font = UIFont.boldSystemFont(ofSize: 20)
                collectionView?.addSubview(noDataLabel!)
            }
        }
        self.view.addSubview(collectionView!)
        collectionView?.register(TZAssetCell.self, forCellWithReuseIdentifier: "TZAssetCell")
        collectionView?.register(TZAssetCameraCell.self, forCellWithReuseIdentifier: "TZAssetCameraCell")
    }
    
    func pushPhotoPrevireViewController(photoPreviewVc: TZPhotoPreviewController, _ needCheckSelectedModels: Bool) {
        
        photoPreviewVc.isSelectOriginalPhoto = isSelectOriginalPhoto
        photoPreviewVc.backButtonClickClosure = { [weak self] (isSelectOriginalPhoto) in
            self?.isSelectOriginalPhoto = isSelectOriginalPhoto
            if needCheckSelectedModels {
                self?.checkSelectedModels()
            }
            self?.collectionView?.reloadData()
            self?.refreshBottomToolBarStatus()
        }
        
        photoPreviewVc.doneButtonClickClosure = { [weak self] (isSelectOriginalPhoto) in
            self?.isSelectOriginalPhoto = isSelectOriginalPhoto
            self?.doneButtonClick()
        }
        
        photoPreviewVc.doneButtonClickClosureCropMode = { [weak self] (cropedImage, asset) in
            self?.didGetAllPhotos(photos: [cropedImage], asset: [asset], infoArr: nil)
            
        }
        
        self.navigationController?.pushViewController(photoPreviewVc, animated: true)
    }
    
    func getSelectedPhotoBytes() {
        // 别的语言可能显示不下
        if TZImagePickerConfig.sharedInstance.preferredLanguage == "vi" && self.view.tz_width <= 320 {
            return
        }
        guard let tzImagePickerVc = self.navigationController as? TZImagePickerController else { return }
        TZImageManager.manager.getPhotosBytes(withArray: tzImagePickerVc.selectedModels) { [weak self] (totalBytes) in
            self?._originalPhotoLabel.text = "(\(totalBytes))"
        }
    }
    
    func refreshBottomToolBarStatus() {
        guard let tzImagePickerVc = self.navigationController as? TZImagePickerController else { return }
        _previewButton.isEnabled = tzImagePickerVc.selectedModels.count > 0
        _doneButton.isEnabled = tzImagePickerVc.selectedModels.count > 0 || tzImagePickerVc.alwaysEnableDoneBtn
        
        _numberImageView?.isHidden = tzImagePickerVc.selectedModels.count <= 0
        _numberLabel?.isHidden = tzImagePickerVc.selectedModels.count <= 0
        _numberLabel?.text = String(format: "%zd", tzImagePickerVc.selectedModels.count)
        
        _originalPhotoButton.isEnabled = tzImagePickerVc.selectedModels.count > 0
        _originalPhotoButton.isSelected = isSelectOriginalPhoto && _originalPhotoButton.isSelected
        _originalPhotoLabel.isHidden = !_originalPhotoButton.isSelected
        
        if isSelectOriginalPhoto {
            self.getSelectedPhotoBytes()
        }
    }
    
    //MARK: Action
    @objc func navLeftBarButtonClick() -> Void {
        self.navigationController?.popViewController(animated: true)
    }
    
    @objc func previewButtonClick() -> Void {
        self.pushPhotoPrevireViewController(photoPreviewVc: TZPhotoPreviewController.init(), true)
    }
    
    @objc func originalPhotoButtonClick() -> Void {
        _originalPhotoButton.isSelected = !_originalPhotoButton.isSelected
        isSelectOriginalPhoto = _originalPhotoButton.isSelected
        _originalPhotoLabel.isHidden = !_originalPhotoButton.isSelected
        if (isSelectOriginalPhoto) {
            self.getSelectedPhotoBytes()
        }
    }
    
    @objc func doneButtonClick() -> Void {
        guard let tzImagePickerVc = self.navigationController as? TZImagePickerController else { return }
        var alertView: UIAlertController?
        if tzImagePickerVc.minImagesCount > 0 && tzImagePickerVc.selectedModels.count < tzImagePickerVc.minImagesCount {
            tzImagePickerVc.showAlertWithTitle(title: String(format: Bundle.tz_localizedString(for: "Select a minimum of %zd photos"), tzImagePickerVc.minImagesCount))
            return
        }
        
        tzImagePickerVc.showProgressHUD()
        var assets: [PHAsset] = []
        var photos: [UIImage] = []
        var infoArr: [[AnyHashable:Any]] = []
        if tzImagePickerVc.onlyReturnAsset {
            for (_,model) in tzImagePickerVc.selectedModels.enumerated() {
                assets.append(model.asset)
            }
        } else {
            for (_,model) in tzImagePickerVc.selectedModels.enumerated() {
                //添加占位数据
                assets.append(model.asset)
                photos.append(UIImage())
                infoArr.append(["":""])
            }
            
            var havenotShowAlert = true
            TZImageManager.manager.shouldFixOrientation = true
            for (index,model) in tzImagePickerVc.selectedModels.enumerated() {
                //entern必须比leave早，因此不能分开
                self.dispatchGroup.enter()
                self.operationQueue.addOperation {
                    DispatchQueue.global().async {
                        TZImageManager.manager.getPhoto(with: model.asset, callback: { [weak self] (photo, info, isDegraded) in

                        if isDegraded == true { return }
                        if TZImagePickerConfig.sharedInstance.notScaleImage == false {
                            let scalePhoto = TZImageManager.manager.scaleImage(photo, to: CGSize(width: tzImagePickerVc.photoWidth, height: tzImagePickerVc.photoWidth*photo.size.height/photo.size.height))
                            photos[index] = scalePhoto
                        } else {
                            photos[index] = photo
                        }
                        if let reinfo = info {
                            infoArr[index] = reinfo
                        }
                        assets[index] = model.asset

                        self?.dispatchGroup.leave()
                        }, progressHandler: { (progress, error, stop, info) in
                            DispatchQueue.main.async {
                                if progress < 1 && havenotShowAlert && alertView == nil {
                                    tzImagePickerVc.hideProgressHUD()
                                    alertView = tzImagePickerVc.showAlertWithTitle(title: Bundle.tz_localizedString(for: "Synchronizing photos from iCloud"))

                                }
                                havenotShowAlert = progress >= 1
                            }
                        }, networkAccessAllowed: true)
                    }
                }
            }
            
            
            self.dispatchGroup.notify(queue: DispatchQueue.main) {
                //等待数据装载完成，返回
                if havenotShowAlert {
                    tzImagePickerVc.hideAlertView(alertView: alertView)
                }
                self.didGetAllPhotos(photos: photos, asset: assets, infoArr: infoArr)
            }
        }
        
        if tzImagePickerVc.selectedModels.count <= 0 || tzImagePickerVc.onlyReturnAsset {
            self.didGetAllPhotos(photos: photos, asset: assets, infoArr: infoArr)
        }
    }
    
    private func takePhoto() {
        let authStatus = AVCaptureDevice.authorizationStatus(for: .video)
        if authStatus == .restricted || authStatus == .denied {
            //没权限
            let infoDict = TZCommonTools.tz_getInfoDictionary()
            var appName: String? = infoDict["CFBundleDisplayName"] as? String
            if appName == nil {
                appName = infoDict["CFBundleName"] as? String ?? ""
            }
            
            let message = String(format: Bundle.tz_localizedString(for: Bundle.tz_localizedString(for: "Please allow %@ to access your camera in \"Settings -> Privacy -> Camera\"")), appName!)
            let alert = UIAlertController.init(title: Bundle.tz_localizedString(for: "Can not user Camera"), message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction.init(title: Bundle.tz_localizedString(for: "Cancel"), style: .cancel, handler: nil))
            alert.addAction(UIAlertAction.init(title: Bundle.tz_localizedString(for: "Setting"), style: .cancel, handler: { _ in
                UIApplication.shared.openURL(URL.init(fileURLWithPath: UIApplication.openSettingsURLString))
            }))
            self.navigationController?.pushViewController(alert, animated: true)
        } else if (authStatus == .notDetermined) {
            AVCaptureDevice.requestAccess(for: .video) { (granted) in
                if granted {
                    DispatchQueue.main.async {
                        self.pushImagePickerController()
                    }
                }
            }
        } else {
            self.pushImagePickerController()
        }
    }
    
    /// 进入相机
    private func pushImagePickerController() {
        if let tzImagePickerVc = self.navigationController as? TZImagePickerController,
            tzImagePickerVc.allowCameraLocation {
            
            let sourceType = UIImagePickerController.SourceType.camera
            if UIImagePickerController.isSourceTypeAvailable(sourceType) {
                self.imagePickerVc.sourceType = sourceType
                var mediaTypes: [String] = []
                if tzImagePickerVc.allowTakePicture {
                    mediaTypes.append(kUTTypeImage as String)
                }
                if tzImagePickerVc.allowTakeVideo {
                    mediaTypes.append(kUTTypeMovie as String)
                    self.imagePickerVc.videoMaximumDuration = tzImagePickerVc.videoMaximumDuration
                }
                self.imagePickerVc.mediaTypes = mediaTypes
                tzImagePickerVc.uiImagePickerControllerSettingClosure?(imagePickerVc)
                self.present(self.imagePickerVc, animated: true, completion: nil)
            } else {
                debugPrint("模拟器中无法打开照相机,请在真机中使用")
            }
        }
    }
    
    private func didGetAllPhotos(photos: Array<UIImage>, asset: Array<PHAsset>, infoArr: [[AnyHashable:Any]]?) -> Void {
        
        guard let tzImagePickerVc = self.navigationController as? TZImagePickerController else { return }
        tzImagePickerVc.hideProgressHUD()
        if tzImagePickerVc.autoDismiss {
            self.navigationController?.dismiss(animated: true, completion: {
                self.callDelegateMethodWithPhotos(photos: photos, asset: asset, infoArr: infoArr)
            })
        } else {
            self.callDelegateMethodWithPhotos(photos: photos, asset: asset, infoArr: infoArr)
        }
    }
    
    private func callDelegateMethodWithPhotos(photos: Array<UIImage>, asset: Array<PHAsset>, infoArr: [[AnyHashable:Any]]?) {
        guard let tzImagePickerVc = self.navigationController as? TZImagePickerController else { return }
        
        if (tzImagePickerVc.allowPickingVideo && tzImagePickerVc.maxImagesCount == 1) {
            if let firstPhoto = photos.first, let firstAsset = asset.first,TZImageManager.manager.isVideo(from: asset.first) {
                
                tzImagePickerVc.didFinishPickingVideoClosure?(firstPhoto, firstAsset)
                
                if tzImagePickerVc.pickerDelegate?.responds(to: #selector(tzImagePickerVc.pickerDelegate?.imagePickerController(picker:didFinishPickingVideo:sourceAssets:))) == true {
                    tzImagePickerVc.pickerDelegate?.imagePickerController?(picker: tzImagePickerVc, didFinishPickingVideo: firstPhoto, sourceAssets: firstAsset)
                }
                return
            }
        }
        
        tzImagePickerVc.pickerDelegate?.imagePickerController?(picker: tzImagePickerVc, didFinishPick: photos, get: asset, isSelectOriginalPhoto: isSelectOriginalPhoto)
        
        tzImagePickerVc.pickerDelegate?.imagePickerController?(picker: tzImagePickerVc, didFinishPick: photos, get: asset, isSelectOriginalPhoto: isSelectOriginalPhoto, infoArray: infoArr ?? [])
        
        tzImagePickerVc.didFinishPickingPhotosClosure?(photos, asset, isSelectOriginalPhoto)
        
        tzImagePickerVc.didFinishPickingPhotosWithInfosClosure?(photos,asset,isSelectOriginalPhoto,infoArr ?? [])
    }
    
    private func scrollCollectionViewToBottom() {
        guard let tzImagePickerVc = self.navigationController as? TZImagePickerController else { return }
        if _shouldScrollToBottom && _models.count > 0 {
            var item: Int = 0
            if tzImagePickerVc.sortAscendingByModificationDate {
                item = _models.count - 1
                if _showTakePhotoBtn {
                    item += 1
                }
            }
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.01) {
                self.collectionView?.scrollToItem(at: IndexPath.init(item: item, section: 0), at: .bottom, animated: false)
                self._shouldScrollToBottom = false
                self.collectionView?.isHidden = false
            }
        } else {
            collectionView?.isHidden = false
        }
    }
    
    private func checkSelectedModels() {
        guard let tzImagePickerVc = self.navigationController as? TZImagePickerController else { return }
        var selectedAssets: [PHAsset] = []
        tzImagePickerVc.selectedModels.compactMap({
            selectedAssets.append($0.asset)
        })
        
        var arr: [TZAssetModel] = []
        for model in _models {
            let temp = model
            temp.isSelected = false
            if selectedAssets.contains(model.asset) {
                temp.isSelected = true
            }
            arr.append(temp)
        }
    }
    
    private func addPHAsset(asset: PHAsset?) {
        guard let tzImagePickerVc = self.navigationController as? TZImagePickerController,
            asset != nil else { return }
        
        let assetModel = TZAssetModel.init(asset: asset!, type: TZImageManager.manager.getAssetType(asset: asset!))
        tzImagePickerVc.hideProgressHUD()
        if tzImagePickerVc.sortAscendingByModificationDate {
            _models.append(assetModel)
        } else {
            _models.insert(assetModel, at: 0)
        }
        
        if tzImagePickerVc.maxImagesCount <= 1 {
            if tzImagePickerVc.allowCrop && asset!.mediaType == .image {
                let photoPreviewVc: TZPhotoPreviewController = TZPhotoPreviewController.init()
                if tzImagePickerVc.sortAscendingByModificationDate {
                    photoPreviewVc.currentIndex = _models.count - 1
                } else {
                    photoPreviewVc.currentIndex = 0
                }
                photoPreviewVc.models = _models
                self.pushPhotoPrevireViewController(photoPreviewVc: photoPreviewVc, false)
            } else {
                tzImagePickerVc.addSelectedModel(with: assetModel)
                self.doneButtonClick()
            }
            return
        }
        
        if tzImagePickerVc.selectedModels.count < tzImagePickerVc.maxImagesCount {
            if !(assetModel.type == .TZAssetModelMediaTypeVideo && !tzImagePickerVc.allowPickingMultipleVideo) {
                let temp = assetModel
                temp.isSelected = true
                tzImagePickerVc.addSelectedModel(with: temp)
                self.refreshBottomToolBarStatus()
            }
        }
        
        collectionView?.isHidden = true
        collectionView?.reloadData()
        
        _shouldScrollToBottom = true
        self.scrollCollectionViewToBottom()
        
    }
    
    //MARK: Asset Caching
    private func updateCachedAssets() {
        self.previousPreheatRect = .zero
    }
    
    //MARK: UIImagePickerControllerDelegate
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true, completion: nil)
        guard let tzImagePickerVc = self.navigationController as? TZImagePickerController else { return }
        let type: String? = info[UIImagePickerController.InfoKey.mediaType] as? String
        if type == "public.image" {
            tzImagePickerVc.showProgressHUD()
            if let photo: UIImage = info[UIImagePickerController.InfoKey.originalImage] as? UIImage {
                TZImageManager.manager.savePhoto(with: photo, location: self.location) { [weak self](asset, error) in
                    if error == nil {
                        self?.addPHAsset(asset: asset)
                    }
                }
                self.location = nil
            }
        } else if (type == "public.movie") {
            tzImagePickerVc.showProgressHUD()
            if let videoUrl = info[UIImagePickerController.InfoKey.mediaURL] as? URL {
                TZImageManager.manager.saveVideo(with: videoUrl) { [weak self](asset, error) in
                    if error == nil {
                        self?.addPHAsset(asset: asset)
                    }
                }
                self.location = nil;
            }
        }
    }
    //MARK: UICollectionViewDataSource
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if _showTakePhotoBtn {
            return _models.count + 1
        }
        return _models.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let tzImagePickerVc = self.navigationController as? TZImagePickerController else { fatalError() }
        if (tzImagePickerVc.sortAscendingByModificationDate && indexPath.item >= _models.count || (!tzImagePickerVc.sortAscendingByModificationDate && indexPath.item == 0)) && _showTakePhotoBtn {
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "TZAssetCameraCell", for: indexPath) as? TZAssetCameraCell  else {
                fatalError()
            }
            cell.imageView?.image = tzImagePickerVc.takePictureImage
            cell.imageView?.contentMode = .center
            let rgb: CGFloat = 223/255.0
            cell.imageView?.backgroundColor = .init(red: rgb, green: rgb, blue: rgb, alpha: 1.0)
            return cell
        }
        
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "TZAssetCell", for: indexPath) as? TZAssetCell  else {
            fatalError()
        }
        cell.allowPickingMultipleVideo = tzImagePickerVc.allowPickingMultipleVideo
        cell.photoDefImage = tzImagePickerVc.photoDefImage
        cell.photoSelImage = tzImagePickerVc.photoSelImage
        
        var assetModel: TZAssetModel
        if tzImagePickerVc.sortAscendingByModificationDate || !_showTakePhotoBtn {
            assetModel = _models[indexPath.item]
        } else {
            assetModel = _models[indexPath.item - 1]
        }
        cell.allowPickingGif = tzImagePickerVc.allowPickingGif
        cell.model = assetModel
        if assetModel.isSelected && tzImagePickerVc.showSelectedIndex {
            cell.index = (tzImagePickerVc.selectedAssetIds.firstIndex(of: assetModel.asset.localIdentifier) ?? 0) + 1
        }
        cell.showSelectBtn = tzImagePickerVc.showSelectBtn
        cell.allowPreview = tzImagePickerVc.allowPreview
        if (tzImagePickerVc.selectedModels.count >= tzImagePickerVc.maxImagesCount && tzImagePickerVc.showPhotoCannotSelectLayer && !assetModel.isSelected) {
            cell.cannotSelectLayerButton.backgroundColor = tzImagePickerVc.cannotSelectLayerColor;
            cell.cannotSelectLayerButton.isHidden = false
        } else {
            cell.cannotSelectLayerButton.isHidden = true
        }
        
        cell.didSelectPhotoClosure = { [weak cell,weak self] (isSelected) in
            if isSelected {
                cell?.selectPhotoButton.isSelected = false
                assetModel.isSelected = false
                for selectedItem in tzImagePickerVc.selectedModels {
                    if selectedItem.asset.localIdentifier == assetModel.asset.localIdentifier {
                        tzImagePickerVc.removeSelectedModel(with: selectedItem)
                    }
                }
                self?.refreshBottomToolBarStatus()
                if (tzImagePickerVc.showSelectedIndex || tzImagePickerVc.showPhotoCannotSelectLayer) {
                    NotificationCenter.default.post(name: Notification.Name.init(rawValue: "TZ_PHOTO_PICKER_RELOAD_NOTIFICATION"), object: self?.navigationController)
                }
                UIView.showOscillatoryAnimationWith(layer: self?._numberImageView?.layer, type: .TZOscillatoryAnimationToSmaller)
            } else {
                // 2. select:check if over the maxImagesCount / 选择照片,检查是否超过了最大个数的限制
                if tzImagePickerVc.selectedModels.count < tzImagePickerVc.maxImagesCount {
                    if (tzImagePickerVc.maxImagesCount == 1 && !tzImagePickerVc.allowPreview) {
                        assetModel.isSelected = true
                        tzImagePickerVc.addSelectedModel(with: assetModel)
                        self?.doneButtonClick()
                        return
                    }
                    cell?.selectPhotoButton.isSelected = true
                    assetModel.isSelected = true
                    tzImagePickerVc.addSelectedModel(with: assetModel)
                    if tzImagePickerVc.showSelectedIndex || tzImagePickerVc.showPhotoCannotSelectLayer {
                        NotificationCenter.default.post(name: Notification.Name.init(rawValue: "TZ_PHOTO_PICKER_RELOAD_NOTIFICATION"), object: self?.navigationController)
                    }
                    self?.refreshBottomToolBarStatus()
                    UIView.showOscillatoryAnimationWith(layer: self?._numberImageView?.layer, type: .TZOscillatoryAnimationToSmaller)
                } else {
                    tzImagePickerVc.showAlertWithTitle(title:String(format: Bundle.tz_localizedString(for:"Select a maximum of %zd photos"), tzImagePickerVc.maxImagesCount))
                }
            }
        }

        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let tzImagePickerVc = self.navigationController as? TZImagePickerController else { return }
        if (((tzImagePickerVc.sortAscendingByModificationDate && indexPath.item >= _models.count) || (!tzImagePickerVc.sortAscendingByModificationDate && indexPath.item == 0)) && _showTakePhotoBtn) {
            self.takePhoto()
            return
        }
        
        var index = indexPath.item
        if !tzImagePickerVc.sortAscendingByModificationDate && _showTakePhotoBtn {
            index = indexPath.item - 1
        }
        let model = _models[index]
        if model.type == .TZAssetModelMediaTypeVideo && !tzImagePickerVc.allowPickingMultipleVideo {
            if tzImagePickerVc.selectedModels.count > 0 {
                tzImagePickerVc.showAlertWithTitle(title: Bundle.tz_localizedString(for: "Can not choose both video and photo"))
            } else {
                let videoPlayerVc = TZVideoPlayerController()
                videoPlayerVc.model = model
                self.navigationController?.pushViewController(videoPlayerVc, animated: true)
            }
        } else if (model.type == .TZAssetModelMediaTypePhotoGif && tzImagePickerVc.allowPickingGif && !tzImagePickerVc.allowPickingMultipleVideo) {
            if tzImagePickerVc.selectedModels.count > 0 {
                tzImagePickerVc.showAlertWithTitle(title: Bundle.tz_localizedString(for: "Can not choose both photo and GIF"))
            } else {
                let gifPreviewVc = TZGifPhotoPreviewController.init(with: model)
                self.navigationController?.pushViewController(gifPreviewVc, animated: true)
            }
        } else {
            let photoPreviewVc = TZPhotoPreviewController.init(with: _models)
            photoPreviewVc.currentIndex = index
            self.pushPhotoPrevireViewController(photoPreviewVc: photoPreviewVc, false)
        }
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        
        guard let tzImagePickerVc = self.navigationController as? TZImagePickerController else {
            return super.preferredStatusBarStyle
        }
        return tzImagePickerVc.statusBarStyle
    }
    
    init() {
        operationQueue = OperationQueue()
        super.init(nibName: nil, bundle: nil)
        // 并发数量为3
        self.operationQueue.maxConcurrentOperationCount = 3
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    deinit {
        self.operationQueue.cancelAllOperations()
        NotificationCenter.default.removeObserver(self)
    }
    override var prefersStatusBarHidden: Bool {
        return false
    }
    @objc func didChangeStatusBarOrientationNotification(noti: Notification) -> Void {
        _offsetItemCount = (collectionView?.contentOffset.y ?? 0.0) / (layout.itemSize.height + layout.minimumLineSpacing)
    }
}

class TZCollectionView: UICollectionView {
    
    override func touchesShouldCancel(in view: UIView) -> Bool {
        if view.isKind(of: UIControl.self) {
            return true
        }
        return super.touchesShouldCancel(in: view)
    }
    
}
