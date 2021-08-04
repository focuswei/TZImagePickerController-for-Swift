//
//  TZImagePickerController.swift
//  TZImagePickerController
//
//  Created by FocusWei on 2019/11/14.
//  Copyright © 2019 FocusWei. All rights reserved.
//

import UIKit
import Photos
@objc protocol TZImagePickerControllerDelegate: NSObjectProtocol {
    
    @objc optional func imagePickerController(picker: TZImagePickerController, didFinishPick photos: Array<UIImage>,get sourceAssets: Array<PHAsset>, isSelectOriginalPhoto: Bool)
    @objc optional func imagePickerController(picker: TZImagePickerController, didFinishPick photos: Array<UIImage>,get sourceAssets: Array<PHAsset>, isSelectOriginalPhoto: Bool, infoArray: [[AnyHashable:Any]]?)
    @objc optional func tz_imagePickerControllerDidCancel(picker: TZImagePickerController)
    
    @objc optional func imagePickerController(picker: TZImagePickerController, didFinishPickingVideo coverImage: UIImage, sourceAssets: PHAsset)
    
    @objc optional func imagePickerController(picker: TZImagePickerController, didFinishPickingGifImage animatedImage: UIImage, sourceAssets: PHAsset)
    
    @objc optional func isAlbumCanSelect(albumName: String, result: PHFetchResult<PHAsset>) -> Bool
    
    @objc optional func isAssetCanSelect(asset: PHAsset) -> Bool
}

class TZImagePickerController: UINavigationController {

    /// Default is 9 / 默认最大可选9张图片
    var maxImagesCount: Int = 9 {
        didSet {
            if maxImagesCount > 1 {
                showSelectBtn = true
                allowCrop = false
            }
        }
    }
    /// The minimum count photos user must pick, Default is 0
    /// 最小照片必选张数,默认是0
    var minImagesCount: Int = 0
    
    /// Always enale the done button, not require minimum 1 photo be picked
    /// 让完成按钮一直可以点击，无须最少选择一张图片
    var alwaysEnableDoneBtn: Bool = true

    /// Sort photos ascending by modificationDate，Default is YES
    /// 对照片排序，按修改时间升序，默认是YES。如果设置为NO,最新的照片会显示在最前面，内部的拍照按钮会排在第一个
    var sortAscendingByModificationDate: Bool = true {
        didSet { TZImageManager.manager.sortAscendingByModificationDate = sortAscendingByModificationDate }
    }
    
    /// The pixel width of output image, Default is 828px / 导出图片的宽度，默认828像素宽
    var photoWidth: CGFloat = 828 {
        didSet { TZImageManager.manager.photoWidth = photoWidth }
    }
    
    /// Default is 600px / 默认600像素宽
    var photoPreviewMaxWidth: CGFloat = 600 {
        didSet {
            if photoPreviewMaxWidth > 800 {
                photoPreviewMaxWidth = 800
            } else if photoPreviewMaxWidth < 500 {
                photoPreviewMaxWidth = 500
            }
            TZImageManager.manager.photoPreviewMaxWidth = photoPreviewMaxWidth
        }
    }
    
    /// Default is 15, While fetching photo, HUD will dismiss automatic if timeout;
    /// 超时时间，默认为15秒，当取图片时间超过15秒还没有取成功时，会自动dismiss HUD；
    var timeout: TimeInterval = 15 {
        didSet {
            if timeout < 5 {
                timeout = 5
            } else if timeout > 60 {
                timeout = 60
            }
        }
    }
    
    /// Default is YES, if set NO, the original photo button will hide. user can't picking original photo.
    /// 默认为YES，如果设置为NO,原图按钮将隐藏，用户不能选择发送原图
    var allowPickingOriginalPhoto: Bool = true
    
    /// Default is YES, if set NO, user can't picking video.
    /// 默认为YES，如果设置为NO,用户将不能选择视频
    var allowPickingVideo: Bool = true {
        didSet {
            TZImagePickerConfig.sharedInstance.allowPickingVideo = allowPickingVideo
            if allowPickingVideo == false {
                allowTakeVideo = false
            }
        }
    }
    var allowPickingMultipleVideo: Bool = false
    var allowPickingGif: Bool = false
    var allowPickingImage: Bool = true {
        didSet {
            TZImagePickerConfig.sharedInstance.allowPickingImage = allowPickingImage
            if allowPickingImage == false {
                allowTakePicture = false
            }
        }
    }
    /// Default is YES, if set NO, user can't take picture.
    /// 默认为YES，如果设置为NO,拍照按钮将隐藏,用户将不能选择照片
    var allowTakePicture: Bool = true
    
    /// Default is YES, if set NO, user can't preview photo.
    /// 默认为YES，如果设置为NO,预览按钮将隐藏,用户将不能去预览照片
    var allowCameraLocation: Bool = true
    
    /// Default is YES, if set NO, the picker don't dismiss itself.
    /// 默认为YES，如果设置为NO, 选择器将不会自己dismiss
    var allowTakeVideo: Bool = true
    
    var videoMaximumDuration: TimeInterval = 10 * 60
    var uiImagePickerControllerSettingClosure: ((_ imagePickerController: UIImagePickerController) -> Void)?
    
    var preferredLanguage: String = "zh-Hant" {
        didSet {
            TZImagePickerConfig.sharedInstance.preferredLanguage = preferredLanguage
            self.configDefaultBtnTitle()
        }
    }
    var languageBundle: Bundle? {
        didSet {
            TZImagePickerConfig.sharedInstance.languageBundle = languageBundle
            self.configDefaultBtnTitle()
        }
    }
    var allowPreview = true
    var autoDismiss = true
    var onlyReturnAsset = false
    var showSelectedIndex = false {
        didSet {
            if showSelectedIndex {
                self.photoSelImage = self.createImageWithColor(color: nil, size: CGSize(width: 24, height: 24), radius: 12)
            }
            TZImagePickerConfig.sharedInstance.showSelectedIndex = showSelectedIndex
        }
    }
    var showPhotoCannotSelectLayer = false {
        didSet {
            TZImagePickerConfig.sharedInstance.showPhotoCannotSelectLayer = showPhotoCannotSelectLayer
        }
    }
    var cannotSelectLayerColor: UIColor = UIColor.init(white: 1, alpha: 0.8)
    var notScaleImage = true {
        didSet {
            TZImagePickerConfig.sharedInstance.notScaleImage = notScaleImage
        }
    }
    var needFixComposition = false {
        didSet {
            TZImagePickerConfig.sharedInstance.needFixComposition = needFixComposition
        }
    }
    /// The photos user have selected
    /// 用户选中过的图片数组
    var selectedAssets: Array<PHAsset> = [] {
        didSet {
            selectedModels.removeAll()
            selectedAssetIds.removeAll()
            let _ = selectedAssets.map({
                let model = TZAssetModel.init(asset: $0, type: TZImageManager.manager.getAssetType(asset: $0))
                model.isSelected = true
                self.addSelectedModel(with: model)
            })
        }
    }
    var selectedModels: Array<TZAssetModel> = []
    var selectedAssetIds: Array<String> = []
    
    /// Minimum selectable photo width, Default is 0
    /// 最小可选中的图片宽度，默认是0，小于这个宽度的图片不可选中
    var minPhotoWidthSelectable: CGFloat = 0 {
        didSet {
            TZImageManager.manager.minPhotoWidthSelectable = minPhotoWidthSelectable
        }
    }
    var minPhotoHeightSelectable: CGFloat = 0 {
        didSet {
            TZImageManager.manager.minPhotoHeightSelectable = minPhotoHeightSelectable
        }
    }
    var hideWhenCanNotSelect = false {
        didSet {
            TZImageManager.manager.hideWhenCanNotSelect = hideWhenCanNotSelect
        }
    }
    
    var statusBarStyle: UIStatusBarStyle = .default
    
    /// 单选模式,maxImagesCount为1时才生效
    ///< 在单选模式下，照片列表页中，显示选择按钮,默认为NO
    var showSelectBtn = false {
        didSet {
            if showSelectBtn == false && maxImagesCount > 1
            { showSelectBtn = true }
        }
    }
    ///< 允许裁剪,默认为YES，showSelectBtn为NO才生效
    var allowCrop: Bool = false {
        didSet {
            allowCrop = maxImagesCount > 1 ? false:allowCrop
            if allowCrop {
                self.allowPickingOriginalPhoto = false
                self.allowPickingGif = false
            }
        }
    }
    ///< 是否图片等比缩放填充cropRect区域
    var scaleAspectFillCrop: Bool = false
    
    ///< 裁剪框的尺寸
    var cropRect: CGRect = .zero {
        didSet {
            cropRectPortrait = cropRect
            cropRectLandscape = CGRect(x: (self.view.tz_height - cropRect.size.width)/2, y: cropRect.origin.x, width: cropRect.size.width, height: cropRect.size.width)
        }
    }
    
    ///< 裁剪框的尺寸(竖屏)
    var cropRectPortrait: CGRect = .zero
    ///< 裁剪框的尺寸(横屏)
    var cropRectLandscape: CGRect = .zero
    ///< 需要圆形裁剪框
    var needCircleCrop: Bool = false
    var circleCropRadius: CGFloat = 0 {
        didSet {
            let x: CGFloat = self.view.tz_width/2 - circleCropRadius
            let y: CGFloat = self.view.tz_height/2 - circleCropRadius
            self.cropRect = CGRect(x: x, y: y, width: circleCropRadius*2, height: circleCropRadius*2)
        }
    }
    
    ///< 自定义裁剪框的其他属性
    var cropViewSettingClosure: ((_ cropView: UIView) -> Void)?
    ///< 自定义返回按钮样式及其属性
    var navLeftBarButtonSettingClosure: ((_ leftButton: UIButton) -> Void)?
    
    var isSelectOriginalPhoto: Bool = true
    var needShowStatusBar: Bool = false
    
    var takePictureImage: UIImage?
    var photoSelImage: UIImage?
    var photoDefImage: UIImage?
    var photoOriginSelImage: UIImage?
    var photoOriginDefImage: UIImage?
    var photoPreviewOriginDefImage: UIImage?
    var photoNumberIconImage: UIImage?
    
    var oKButtonTitleColorNormal: UIColor = UIColor.doneButtonTitleColor
    var oKButtonTitleColorDisabled: UIColor = UIColor.doneButtonTitleColor
    var naviBgColor: UIColor? {
        didSet { self.navigationBar.barTintColor = naviBgColor }
    }
    var naviTitleColor: UIColor? {
        didSet { self.configNaviTitleAppearance() }
    }
    var naviTitleFont: UIFont? {
        didSet { self.configNaviTitleAppearance() }
    }
    var barItemTextColor: UIColor? {
        didSet { self.configNaviTitleAppearance() }
    }
    var barItemTextFont: UIFont? {
        didSet { self.configNaviTitleAppearance() }
    }
    
    var doneBtnTitleStr: String = Bundle.tz_localizedString(for: "Done")
    var cancelBtnTitleStr: String = Bundle.tz_localizedString(for: "Cancel")
    var previewBtnTitleStr: String = Bundle.tz_localizedString(for: "Preview")
    var fullImageBtnTitleStr: String = Bundle.tz_localizedString(for: "Full image")
    var settingBtnTitleStr: String  = Bundle.tz_localizedString(for: "Setting")
    var processHintStr: String = Bundle.tz_localizedString(for: "Processing...")
    
    var iconThemeColor: UIColor? {
        didSet { self.configDefaultImageName() }
    }
    
    var didFinishPickingPhotosClosure: ((_ photos: Array<UIImage>, _ assets: Array<PHAsset>, _ isSelectOriginalPhoto: Bool) -> Void)?
    var didFinishPickingPhotosWithInfosClosure: ((_ photos: Array<UIImage>, _ assets: Array<PHAsset>, _ isSelectOriginalPhoto: Bool, _ info: [[AnyHashable:Any]]) ->Void)?
    var imagePickerControllerDidCancelClosure: (() -> Void)?
    
    // If user picking a video, this handle will be called.
    // 如果用户选择了一个视频，下面的handle会被执行
    var didFinishPickingVideoClosure: ((_ coverImage: UIImage, _ asset: PHAsset) ->Void)?
    // If user picking a gif image, this callback will be called.
    // 如果用户选择了一个gif图片，下面的handle会被执行
    var didFinishPickingGifImageClosure: ((_ animatedImage: UIImage, _ sourceAssets: Array<PHAsset>) -> Void)?
    weak var pickerDelegate: TZImagePickerControllerDelegate? {
        didSet { TZImageManager.manager.pickerDelegate = pickerDelegate }
    }
    
    private var timer: Timer?
    private var tipLabel: UILabel?
    private var settingBtn: UIButton = UIButton.init(type: .system)
    private var pushPhotoPickerVc: Bool = false
    private var didPushPhotoPickerVc: Bool = false
    private var progressHud: UIButton?
    private var HUDContainer: UIView?
    private var HUDIndicatorView: UIActivityIndicatorView?
    private var HUDLabel: UILabel?
    private var originStatusBarStyle: UIStatusBarStyle = TZCommonTools.getStatusBarStyle()
    private var columnNumber: Int = 4 {
        didSet {
            if columnNumber <= 2 {
                columnNumber = 2
            } else if columnNumber >= 6 {
                columnNumber = 6
            }
            if let albumPickerVc = self.children.first as? TZAlbumPickerController {
                albumPickerVc.columnNumber = columnNumber
            }
            TZImageManager.manager.columnNumber = columnNumber
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        originStatusBarStyle = TZCommonTools.getStatusBarStyle()
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        UIApplication.shared.statusBarStyle = originStatusBarStyle
        self.hideProgressHUD()
    }
    override func viewDidLoad() {
        super.viewDidLoad()

        self.needShowStatusBar = !TZCommonTools.isStatusBarHidden()
        self.navigationBar.isTranslucent = true
        TZImageManager.manager.shouldFixOrientation = false
        
        self.setAppearanceColor()
        self.automaticallyAdjustsScrollViewInsets = false
        if self.needShowStatusBar {
            UIApplication.shared.isStatusBarHidden = false
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let progressHUDY = self.navigationBar.frame.maxY
        progressHud?.frame = CGRect(x: 0, y: progressHUDY, width: self.view.tz_width, height: self.view.tz_height - progressHUDY)
        if let progressHUD = self.progressHud {
            HUDContainer?.frame = CGRect(x: (self.view.tz_width-120.0)/2, y: (progressHUD.tz_height - 90.0 - progressHUDY)/2, width: 120, height: 90)
        }
        HUDIndicatorView?.frame = CGRect(x: 45, y: 15, width: 30, height: 30)
        HUDLabel?.frame = CGRect(x: 0, y: 40, width: 120, height: 50)
        
    }
    
    
        
    convenience init(take maxImagesCount: Int, delegate: TZImagePickerControllerDelegate?) {
        self.init(take: maxImagesCount, columnNumber: 4, delegate: delegate, pushPhotoPickerVc: true)
    }
    
    convenience init(take maxImagesCount: Int, columnNumber: Int, delegate: TZImagePickerControllerDelegate?) {
        self.init(take: maxImagesCount, columnNumber: columnNumber, delegate: delegate, pushPhotoPickerVc: true)
    }
    
    init(take maxImagesCount: Int, columnNumber: Int, delegate: TZImagePickerControllerDelegate?, pushPhotoPickerVc: Bool) {
        
        
        let albumPickerVc = TZAlbumPickerController()
        albumPickerVc.isFirstAppear = true
        albumPickerVc.columnNumber = columnNumber
        super.init(rootViewController: albumPickerVc)
        
        self.changeConfigureValue(take: maxImagesCount, columnNumber: columnNumber, delegate: delegate, pushPhotoPickerVc: pushPhotoPickerVc)
        self.configDefaultSetting()
        
        if !TZImageManager.manager.authorizationStatusAuthorized() {
            self.tipLabel = UILabel.init()
            tipLabel?.frame = CGRect(x: 8, y: 120, width: self.view.tz_width, height: 60)
            tipLabel?.textAlignment = .center;
            tipLabel?.numberOfLines = 0;
            tipLabel?.font = UIFont.systemFont(ofSize: 16)
            tipLabel?.textColor = UIColor.black
            
            let infoDict = TZCommonTools.tz_getInfoDictionary()
            if let appName = infoDict["CFBundleDisplayName"] as? String {
                tipLabel?.text = String(format: Bundle.tz_localizedString(for: "Allow %@ to access your album in \"Settings -> Privacy -> Photos\""), appName)
                self.view.addSubview(tipLabel!)
            }
            
            
            settingBtn.setTitle(self.settingBtnTitleStr, for: .normal)
            settingBtn.frame = CGRect(x: 0, y: 180, width: self.view.tz_width, height: 44)
            settingBtn.addTarget(self, action: #selector(settingBtnClick), for: .touchUpInside)
            self.view.addSubview(settingBtn)
            
            if PHPhotoLibrary.authorizationStatus() == .notDetermined {
                timer = Timer.scheduledTimer(timeInterval: 0.2, target: self, selector: #selector(observeAuthrizationStatusChange), userInfo: nil, repeats: false)
            }
        } else {
            self.pushPhotoVc()
        }
    }
    
    init(with selectedAssets: Array<PHAsset>, selectedPhotos: Array<UIImage>, index: Int) {
        let previewVc = TZPhotoPreviewController()
        super.init(rootViewController: previewVc)
        self.changeConfigureValue(selectedAssets: selectedAssets, allowPickingOriginalPhoto: self.allowPickingOriginalPhoto)
        self.configDefaultSetting()
        
        previewVc.photos = selectedPhotos
        previewVc.currentIndex = index
        previewVc.doneButtonClickClosureWithPreviewType = { [weak self] (photos, assets, isSelectOriginalPhoto) in
            self?.dismiss(animated: true, completion: {
                self?.didFinishPickingPhotosClosure?(photos, assets, isSelectOriginalPhoto)
            })
        }
    }
    
    init(cropTypeWith asset: PHAsset, selectedPhoto: UIImage, callback: ((_ cropImage: UIImage, _ asset: PHAsset) -> Void)?) {
        let previewVc = TZPhotoPreviewController()
        maxImagesCount = 1
        allowPickingImage = true
        allowCrop = true
        selectedAssets = [asset]
        
        super.init(rootViewController: previewVc)
        self.configDefaultSetting()
        
        previewVc.photos = [selectedPhoto]
        previewVc.isCropImage = true
        previewVc.currentIndex = 0
        
        previewVc.doneButtonClickClosureCropMode = { [weak self] (cropImage, asset) in
            self?.dismiss(animated: true, completion: {
                callback?(cropImage, asset)
            })
        }
        
    }
    
    func configDefaultSetting() {
        self.timeout = 15
        self.photoWidth = 828.0
        self.photoPreviewMaxWidth = 600
        self.naviTitleColor = UIColor.white
        self.naviTitleFont = UIFont.systemFont(ofSize: 17)
        self.barItemTextFont = UIFont.systemFont(ofSize: 15)
        self.barItemTextColor = .white
        self.allowPreview = true
        
        self.sortAscendingByModificationDate = true
        self.allowPickingVideo = true
        self.allowPickingImage = true
        self.notScaleImage = true
        self.needFixComposition = false
        self.statusBarStyle = .lightContent
        self.cannotSelectLayerColor = UIColor.init(white: 1, alpha: 0.8)
        self.allowCameraLocation = true
        
        self.iconThemeColor = UIColor.iconThemeColor
        self.configDefaultBtnTitle()
        
        let cropViewWH: CGFloat = CGFloat.minimum(self.view.tz_width, self.view.tz_height)/3*2
        self.cropRect = CGRect(x: (self.view.tz_width - cropViewWH)/2, y: (self.view.tz_height - cropViewWH)/2, width: cropViewWH, height: cropViewWH)
    }
    
    func configDefaultImageName() {
        self.takePictureImage = UIImage.tz_imageNamedFromMyBundle(name: "takePicture80")
        self.photoSelImage = UIImage.tz_imageNamedFromMyBundle(name: "photo_sel_photoPickerVc")
        self.photoDefImage = UIImage.tz_imageNamedFromMyBundle(name: "photo_def_photoPickerVc")
        if let image = self.createImageWithColor(color: nil, size: CGSize(width: 24, height: 24), radius: 12) {
            self.photoNumberIconImage = image
        }
        self.photoPreviewOriginDefImage = UIImage.tz_imageNamedFromMyBundle(name: "preview_original_def")
        self.photoOriginDefImage = UIImage.tz_imageNamedFromMyBundle(name: "photo_original_def")
        self.photoOriginSelImage = UIImage.tz_imageNamedFromMyBundle(name: "photo_original_sel")
    }
    
    func setAppearanceColor() {
        self.view.backgroundColor = UIColor.white
        self.navigationBar.barStyle = .black
        self.navigationBar.barTintColor = UIColor.toolBarBgColor
        
    }
    
    func addSelectedModel(with assetModel: TZAssetModel) {
        self.selectedModels.append(assetModel)
        self.selectedAssetIds.append(assetModel.asset.localIdentifier)
    }
    
    func removeSelectedModel(with assetModel: TZAssetModel) {
        
        selectedModels.removeAll { (model) -> Bool in
            model == assetModel
        }
        selectedAssetIds.removeAll { (Ids) -> Bool in
            Ids == assetModel.asset.localIdentifier
        }

    }
    
    func showAlertWithTitle(title: String) -> UIAlertController {
        let alertController = UIAlertController.init(title: title, message: nil, preferredStyle: .alert)
        alertController.addAction(UIAlertAction.init(title: Bundle.tz_localizedString(for: "OK"), style: .default, handler: nil))
        self.present(alertController, animated: true, completion: nil)
        return alertController
    }
    
    func hideAlertView(alertView: UIAlertController?) {
        alertView?.dismiss(animated: true, completion: nil)
    }
    
    func showProgressHUD() {
        if self.progressHud == nil {
            progressHud = UIButton.init(type: .custom)
            progressHud?.backgroundColor = .clear
            
            HUDContainer = UIView.init()
            HUDContainer?.layer.cornerRadius = 8
            HUDContainer?.clipsToBounds = true
            HUDContainer?.backgroundColor = .darkGray
            HUDContainer?.alpha = 0.7
            
            HUDIndicatorView = UIActivityIndicatorView.init(style: UIActivityIndicatorView.Style.white)
            HUDLabel = UILabel.init()
            HUDLabel?.textAlignment = .center
            HUDLabel?.text = self.processHintStr
            HUDLabel?.font = UIFont.systemFont(ofSize: 15)
            HUDLabel?.textColor = .white
            
            HUDContainer?.addSubview(HUDLabel!)
            HUDContainer?.addSubview(HUDIndicatorView!)
            progressHud?.addSubview(HUDContainer!)
            
        }
        
        HUDIndicatorView?.startAnimating()
        if let applicationWindow: UIWindow = self.view.window {
            applicationWindow.addSubview(progressHud!)
        }
        self.view.setNeedsLayout()
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + self.timeout) { [weak self] in
            self?.hideProgressHUD()
        }
        
    }
    
    func hideProgressHUD() {
        DispatchQueue.main.async { [weak self] in
            self?.HUDIndicatorView?.stopAnimating()
            self?.progressHud?.removeFromSuperview()
        }
    }
    
    @objc func cancelButtonClick() {
        if self.autoDismiss {
            self.dismiss(animated: true) {
                self.callDelegateMethod()
            }
        } else {
            self.callDelegateMethod()
        }
    }
    
    func callDelegateMethod() {
        if self.pickerDelegate?.responds(to: #selector(self.pickerDelegate?.tz_imagePickerControllerDidCancel(picker:))) == true {
            self.pickerDelegate?.tz_imagePickerControllerDidCancel?(picker: self)
        }
        
        self.imagePickerControllerDidCancelClosure?()
    }
    
    func preferredStatusBarStyle() -> UIStatusBarStyle {
        return self.statusBarStyle
    }
    
    private func pushPhotoVc() {
        didPushPhotoPickerVc = false
        if didPushPhotoPickerVc == false && pushPhotoPickerVc {
            let photoPickerVc = TZPhotoPickerController.init()
            photoPickerVc.isFirstAppear = true
            photoPickerVc.columnNumber = self.columnNumber
            TZImageManager.manager.getCameraRollAlbum(allowPickingVideo: self.allowPickingVideo, allowPickingImage: self.allowPickingImage, needFetchAssets: false) { [weak self] (model) in
                photoPickerVc.model = model
                self?.pushViewController(photoPickerVc, animated: true)
                self?.didPushPhotoPickerVc = true
            }
        }
    }
    
    @objc private func settingBtnClick() {
        if #available(iOS 10.0, *) {
            if let url = URL.init(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        } else {
            UIApplication.shared.openURL(URL.init(fileURLWithPath: UIApplication.openSettingsURLString))
        }
    }
    
    @objc private func observeAuthrizationStatusChange() {
        timer?.invalidate()
        if PHPhotoLibrary.authorizationStatus() == .notDetermined {
            timer = Timer.scheduledTimer(timeInterval: 0.2, target: self, selector: #selector(observeAuthrizationStatusChange), userInfo: nil, repeats: false)
        }
        
        if TZImageManager.manager.authorizationStatusAuthorized() {
            tipLabel?.removeFromSuperview()
            settingBtn.removeFromSuperview()
            self.pushPhotoVc()
            
            if let albumPickerVc = self.visibleViewController as? TZAlbumPickerController {
                albumPickerVc.configTableView()
            }
        }
    }
    override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        viewController.automaticallyAdjustsScrollViewInsets = false
        super.pushViewController(viewController, animated: animated)
    }
    
    //MARK: UIContentContainer
    override func viewWillTransition(to size: CGSize, with transitionCoordinator: UIViewControllerTransitionCoordinator) {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + DispatchTimeInterval.milliseconds(20)) {
            if TZCommonTools.isStatusBarHidden(),
            self.needShowStatusBar {
                UIApplication.shared.isStatusBarHidden = false
            }
        }
        
        if size.width < size.height {
            cropRect = cropRectLandscape
        } else {
            cropRect = cropRectPortrait
        }
    }
    
    //MARK: private func
    
    private func createImageWithColor(color: UIColor?, size: CGSize, radius: CGFloat) -> UIImage? {
        var newColor = color
        if newColor == nil {
            newColor = self.iconThemeColor
        }
        let rect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        UIGraphicsBeginImageContextWithOptions(rect.size, false, UIScreen.main.scale)
        let context = UIGraphicsGetCurrentContext()
        context?.setFillColor(newColor!.cgColor)
        let path = UIBezierPath.init(roundedRect: rect, cornerRadius: radius)
        context?.addPath(path.cgPath)
        context?.fillPath()
        let image = UIGraphicsGetImageFromCurrentImageContext()
        return image
    }
    
    private func configBarButtonItemAppearance() {
        let barItem: UIBarButtonItem = UIBarButtonItem.appearance(whenContainedInInstancesOf:[ TZImagePickerController.self])
        var textAttrs: [NSAttributedString.Key:Any] = [:]
        if let barItemTextColor = self.barItemTextColor {
            textAttrs[NSAttributedString.Key.foregroundColor] = barItemTextColor
        }
        if let barItemTextFont = self.barItemTextFont {
            textAttrs[NSAttributedString.Key.font] = barItemTextFont
        }
        barItem.setTitleTextAttributes(textAttrs, for: .normal)
    }
    
    private func configDefaultBtnTitle() {
        self.doneBtnTitleStr = Bundle.tz_localizedString(for: "Done")
        self.cancelBtnTitleStr = Bundle.tz_localizedString(for: "Cancel")
        self.previewBtnTitleStr = Bundle.tz_localizedString(for: "Preview")
        self.fullImageBtnTitleStr = Bundle.tz_localizedString(for: "Full image")
        self.settingBtnTitleStr = Bundle.tz_localizedString(for: "Setting")
        self.processHintStr = Bundle.tz_localizedString(for: "Processing...")
    }
    
    private func changeConfigureValue(take maxImagesCount: Int, columnNumber: Int, delegate: TZImagePickerControllerDelegate?, pushPhotoPickerVc: Bool) {
        //初始化的时候 didSet 和willSet 不会被调用
        self.columnNumber = columnNumber
        self.maxImagesCount = maxImagesCount > 0 ? maxImagesCount:9
        self.pickerDelegate = delegate
        self.pushPhotoPickerVc = pushPhotoPickerVc
    }
    
    private func changeConfigureValue(selectedAssets: [PHAsset], allowPickingOriginalPhoto: Bool) {
        self.selectedAssets = selectedAssets
        self.allowPickingOriginalPhoto = allowPickingOriginalPhoto
    }
    
    private func configNaviTitleAppearance() {
        var textAttr: [NSAttributedString.Key:Any] = [:]
        if self.naviTitleColor != nil {
            textAttr[NSAttributedString.Key.foregroundColor] = self.naviTitleColor!
        }
        if self.naviTitleFont != nil {
            textAttr[NSAttributedString.Key.font] = self.naviTitleFont
        }
        self.navigationBar.titleTextAttributes = textAttr
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nil, bundle: nil)
    }
    
}


