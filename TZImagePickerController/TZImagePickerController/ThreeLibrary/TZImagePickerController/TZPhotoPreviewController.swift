//
//  TZPhotoPreviewController.swift
//  TZImagePickerController
//
//  Created by FocusWei on 2019/11/26.
//  Copyright © 2019 FocusWei. All rights reserved.
//

import UIKit
import Photos.PHAsset

class TZPhotoPreviewController: UIViewController,UICollectionViewDataSource,UICollectionViewDelegate {
    
    /// All photo models / 所有图片模型数组
    var models: [TZAssetModel] = []
    ///< All photos  / 所有图片数组
    var photos: [UIImage]? {
        didSet {
            photosTemp = photos ?? []
        }
    }
    
    private var currentIndexTemp: Int = 0
    ///< Index of the photo user click / 用户点击的图片的索引
    var currentIndex: Int {
        get {
            return TZCommonTools.tz_isRightToLeftLayout() ? self.models.count - currentIndexTemp - 1:currentIndexTemp
        }
        set {
            currentIndexTemp = newValue
        }
    }
    ///< If YES,return original photo / 是否返回原图，默认是false
    var isSelectOriginalPhoto: Bool = false {
        didSet {
            didSetIsSelectOriginalPhoto = true
        }
    }
    var isCropImage: Bool = false
    
    /// Return the new selected photos / 返回最新的选中图片数组
    var backButtonClickClosure: ((_ isSelectOriginalPhoto: Bool) -> Void)?
    var doneButtonClickClosure: ((_ isSelectOriginalPhoto: Bool) -> Void)?
    var doneButtonClickClosureCropMode: ((_ cropedImage: UIImage, _ asset: PHAsset) -> Void)?
    var doneButtonClickClosureWithPreviewType: ((_ photos: [UIImage], _ assets: [PHAsset], _ isSelectOriginalPhoto: Bool) -> Void)?
    
    private var collectionView: UICollectionView!
    private var layout: UICollectionViewFlowLayout!
    private var photosTemp: [UIImage] = []
    private var assetsTemp: [PHAsset] = []
    
    private var naviBar: UIView!
    private var backButton: UIButton!
    private var selectButton: UIButton!
    private var indexLabel: UILabel!
    
    private var toolBar: UIView = UIView.init(frame: .zero)
    private var doneButton: UIButton = UIButton.init(type: .custom)
    private var numberImageView: UIImageView = UIImageView.init()
    private var numberLabel: UILabel = UILabel.init(frame: .zero)
    private var originalPhotoButton: UIButton = UIButton.init(type: .custom)
    private var originalPhotoLabel: UILabel = UILabel.init(frame: .zero)
    private var offsetItemCount: CGFloat = 0
    
    private var didSetIsSelectOriginalPhoto: Bool = false
    
    private var isHideNavibar: Bool = false
    private var cropBgView: UIView = UIView.init(frame: .zero)
    private var cropView: UIView = UIView.init(frame: .zero)
    private var progress: Double = 0
    private var alertView: UIAlertController?
    
    private var isHideStatusBar = true {
        didSet {
            self.setNeedsStatusBarAppearanceUpdate()
        }
    }
    override var prefersStatusBarHidden: Bool {
        return isHideStatusBar
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        TZImageManager.manager.shouldFixOrientation = true
        guard let tzImagePickerVc = self.navigationController as? TZImagePickerController else { return }
        if !didSetIsSelectOriginalPhoto {
            didSetIsSelectOriginalPhoto = tzImagePickerVc.isSelectOriginalPhoto
        }
        if self.models.isEmpty {
            self.models = tzImagePickerVc.selectedModels
            self.assetsTemp = tzImagePickerVc.selectedAssets
        }
        self.configCollectionView()
        self.configCustomNaviBar()
        self.configBottomToolBar()
        self.view.clipsToBounds = true
        
        NotificationCenter.default.addObserver(self, selector: #selector(didChangeStatusBarOrientationNotification(_:)), name: UIApplication.didChangeStatusBarOrientationNotification, object: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(true, animated: true)
        self.isHideStatusBar = true
        if currentIndex > 0 {
            collectionView.setContentOffset(CGPoint(x: (self.view.tz_width + 20)*CGFloat(self.currentIndex), y: 9), animated: false)
        }
        self.refreshNaviBarAndBottomBarState()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillAppear(animated)

        guard let tzImagePickerVc = self.navigationController as? TZImagePickerController else { return }
        if tzImagePickerVc.needShowStatusBar {
            self.isHideStatusBar = false
        }
        self.navigationController?.setNavigationBarHidden(false, animated: true)
        TZImageManager.manager.shouldFixOrientation = false
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let tzImagePickerVc = self.navigationController as? TZImagePickerController else { return }
        
        let isFullScreen = self.view.tz_height == UIScreen.main.bounds.size.height
        let statusBarHeight: CGFloat = isFullScreen ? TZCommonTools.tz_statusBarHeight():0
        let statusBarHeightInterval: CGFloat = isFullScreen ? statusBarHeight - 20:0
        let naviBarHeight = statusBarHeight + tzImagePickerVc.navigationBar.tz_height
        naviBar.frame = CGRect(x: 0, y: 0, width: self.view.tz_width, height: naviBarHeight)
        backButton.frame = CGRect(x: 10, y: 10 + statusBarHeightInterval, width: 44, height: 44)
        selectButton.frame = CGRect(x: self.view.tz_width - 56, y: 10 + statusBarHeightInterval, width: 44, height: 44)
        indexLabel.frame = selectButton.frame
        
        layout.itemSize = CGSize(width: self.view.tz_width + 20, height: self.view.tz_height)
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 0
        collectionView.frame = CGRect(x: -10, y: 0, width: self.view.tz_width + 20, height: self.view.tz_height)
        collectionView.setCollectionViewLayout(layout, animated: false)
        if offsetItemCount > 0 {
            let offsetX: CGFloat = offsetItemCount*layout.itemSize.width
            collectionView.setContentOffset(CGPoint(x: offsetX, y: 0), animated: false)
        }
        if tzImagePickerVc.allowCrop {
            collectionView.reloadData()
        }
        
        let toolBarHeight: CGFloat = TZCommonTools.tz_isIPhoneX() ? 44+(83-49):44
        let toolBarTop: CGFloat = self.view.tz_height - toolBarHeight
        toolBar.frame = CGRect(x: 0, y: toolBarTop, width: self.view.tz_width, height: toolBarHeight)
        if tzImagePickerVc.allowPickingOriginalPhoto {
            let fullImageWidth: CGFloat = tzImagePickerVc.fullImageBtnTitleStr.boundingRect(with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude), options: NSStringDrawingOptions.usesFontLeading, attributes: [NSAttributedString.Key.font:UIFont.systemFont(ofSize: 13)], context: nil).width
            originalPhotoButton.frame = CGRect(x: 0, y: 0, width: fullImageWidth+55, height: 44)
            originalPhotoLabel.frame = CGRect(x:fullImageWidth + 42, y:0, width:80, height:44)
        }
        
        doneButton.sizeToFit()
        doneButton.frame = CGRect(x: self.view.tz_width - doneButton.tz_width - 12, y: 0, width: doneButton.tz_width, height: 44)
        numberImageView.frame = CGRect(x: doneButton.tz_left - 24 - 5, y: 10, width: 24, height: 24)
        numberLabel.frame = numberImageView.frame
        
        self.configCropView()
        
        
    }
    
    //MARK: UIScrollViewDelegate
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        var offSetWidth = scrollView.contentOffset.x
        offSetWidth = offSetWidth + ((self.view.tz_width+20) * 0.5)
        
        let currentIndex: Int = Int(offSetWidth/(self.view.tz_width+20))
        if currentIndex < models.count && self.currentIndex != currentIndex {
            self.currentIndexTemp = currentIndex
            self.refreshNaviBarAndBottomBarState()
        }
        
        NotificationCenter.default.post(name: NSNotification.Name.init(rawValue: "photoPreviewCollectionViewDidScroll"), object: nil)
    }
    
    //MARK: UICollectionViewDataSource
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return models.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let tzImagePickerVc = self.navigationController as? TZImagePickerController
        let model = models[indexPath.item]
        
        if tzImagePickerVc?.allowPickingMultipleVideo == true && model.type == .TZAssetModelMediaTypeVideo {
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "TZVideoPreviewCell", for: indexPath) as? TZVideoPreviewCell else { fatalError() }
            cell.model = model
            cell.singleTapGestureClosure = { [weak self] in
                self?.didTapPreviewCell()
            }
            return cell
        } else if tzImagePickerVc?.allowPickingMultipleVideo == true && model.type == .TZAssetModelMediaTypePhotoGif && tzImagePickerVc?.allowPickingGif == true {
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "TZGifPreviewCell", for: indexPath) as? TZGifPreviewCell else { fatalError() }
            cell.model = model
            cell.singleTapGestureClosure = { [weak self] in
                self?.didTapPreviewCell()
            }
            return cell
        } else {
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "TZPhotoPreviewCell", for: indexPath) as? TZPhotoPreviewCell else { fatalError() }
            cell.cropRect = tzImagePickerVc?.cropRect ?? CGRect.zero
            cell.allowCrop = tzImagePickerVc?.allowCrop ?? false
            cell.scaleAspectFillCrop = tzImagePickerVc?.scaleAspectFillCrop
            cell.imageProgressUpdateClosure = { [weak self,weak cell,weak tzImagePickerVc] (progress: Double) in
                self?.progress = progress
                if progress >= 1 {
                    if self?.isSelectOriginalPhoto == true {
                        self?.showPhotoBytes()
                    }
                    if self?.alertView != nil && self?.collectionView.visibleCells.contains(cell!) == true {
                        tzImagePickerVc?.hideAlertView(alertView: self?.alertView)
                        self?.alertView = nil
                        self?.doneButtonClick()
                    }
                }
            }
            cell.model = model
            cell.singleTapGestureClosure = { [weak self] in
                self?.didTapPreviewCell()
            }
            return cell
        }

    }
    
    //MARK: UICollectionViewDelegate
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if let photoPreviewCell = cell as? TZPhotoPreviewCell {
            photoPreviewCell.recoverSubviews()
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if let photoPreViewCell = cell as? TZPhotoPreviewCell {
            photoPreViewCell.recoverSubviews()
        } else if let videoPreViewCell = cell as? TZVideoPreviewCell {
            videoPreViewCell.pausePlayerAndShowNaviBar()
        }
    }
    
    
    
    private func configCustomNaviBar() {
        guard let tzImagePickerVc = self.navigationController as? TZImagePickerController else { return }
        naviBar = UIView.init(frame: .zero)
        naviBar.backgroundColor = UIColor.toolBarBgColor
        
        backButton = UIButton.init(frame: .zero)
        backButton.setImage(UIImage.tz_imageNamedFromMyBundle(name: "navi_back"), for: .normal)
        backButton.setTitleColor(.white, for: .normal)
        backButton.addTarget(self, action: #selector(backButtonClick), for: .touchUpInside)
        
        selectButton = UIButton.init(frame: .zero)
        selectButton.setImage(tzImagePickerVc.photoDefImage, for: .normal)
        selectButton.setImage(tzImagePickerVc.photoSelImage, for: .selected)
        selectButton.imageEdgeInsets = UIEdgeInsets(top: 10, left: 0, bottom: 10, right: 0)
        selectButton.imageView?.contentMode = .scaleAspectFit
        selectButton.addTarget(self, action: #selector(selectButtonClick(_:)), for: .touchUpInside)
        selectButton.isHidden = !tzImagePickerVc.showSelectBtn
        
        indexLabel = UILabel.init(frame: .zero)
        indexLabel.font = UIFont.systemFont(ofSize: 14.0)
        indexLabel.textColor = .white
        indexLabel.textAlignment = .center
        
        naviBar.addSubview(selectButton)
        naviBar.addSubview(indexLabel)
        naviBar.addSubview(backButton)
        self.view.addSubview(naviBar)
    }
    
    private func configBottomToolBar() {
        
        toolBar.backgroundColor = UIColor.toolBarBgColor
        guard let tzImagePickerVc = self.navigationController as? TZImagePickerController else { return }
        
        if tzImagePickerVc.allowPickingOriginalPhoto {
            let leftInset: CGFloat = TZCommonTools.tz_isRightToLeftLayout() ? 10:-10
            originalPhotoButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: leftInset, bottom: 0, right: 0)
            originalPhotoButton.backgroundColor = .clear
            originalPhotoButton.addTarget(self, action: #selector(originalPhotoButtonClick(_:)), for: .touchUpInside)
            originalPhotoButton.titleLabel?.font = UIFont.systemFont(ofSize: 13.0)
            originalPhotoButton.setTitle(tzImagePickerVc.fullImageBtnTitleStr, for: .normal)
            originalPhotoButton.setTitle(tzImagePickerVc.fullImageBtnTitleStr, for: .selected)
            originalPhotoButton.setTitleColor(.lightGray, for: .normal)
            originalPhotoButton.setTitleColor(.white, for: .selected)
            originalPhotoButton.setImage(tzImagePickerVc.photoPreviewOriginDefImage, for: .normal)
            originalPhotoButton.setImage(tzImagePickerVc.photoOriginSelImage, for: .selected)
            
            originalPhotoLabel = UILabel.init(frame: .zero)
            originalPhotoLabel.textAlignment = .left
            originalPhotoLabel.font = UIFont.systemFont(ofSize: 13.0)
            originalPhotoLabel.textColor = .white
            originalPhotoLabel.backgroundColor = .clear
            if isSelectOriginalPhoto {
                self.showPhotoBytes()
            }
            toolBar.addSubview(originalPhotoLabel)
            toolBar.addSubview(originalPhotoButton)
        }
        
        doneButton = UIButton.init(type: .custom)
        doneButton.titleLabel?.font = UIFont.systemFont(ofSize: 16.0)
        doneButton.addTarget(self, action: #selector(doneButtonClick), for: .touchUpInside)
        doneButton.setTitle(tzImagePickerVc.doneBtnTitleStr, for: .normal)
        doneButton.setTitleColor(tzImagePickerVc.oKButtonTitleColorNormal, for: .normal)
        
        numberImageView = UIImageView.init(image: tzImagePickerVc.photoNumberIconImage)
        numberImageView.backgroundColor = .clear
        numberImageView.clipsToBounds = true
        numberImageView.contentMode = .scaleAspectFit
        numberImageView.isHidden = tzImagePickerVc.selectedModels.count <= 0
        
        
        numberLabel.font = UIFont.systemFont(ofSize: 15.0)
        numberLabel.textColor = .white
        numberLabel.textAlignment = .center
        numberLabel.text = String(format: "%zd", tzImagePickerVc.selectedModels.count)
        numberLabel.isHidden = tzImagePickerVc.selectedModels.count <= 0
        numberLabel.backgroundColor = .clear
        
        
        toolBar.addSubview(doneButton)
        toolBar.addSubview(numberImageView)
        toolBar.addSubview(numberLabel)
        self.view.addSubview(toolBar)
        
    }
    
    private func configCollectionView() {
        layout = UICollectionViewFlowLayout.init()
        layout.scrollDirection = .horizontal
        collectionView = UICollectionView.init(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .black
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.isPagingEnabled = true
        collectionView.scrollsToTop = false
        collectionView.showsHorizontalScrollIndicator = false
        let width: CGFloat = CGFloat(self.models.count)*(self.view.tz_width + 20.0)
        collectionView.contentSize = CGSize(width: width, height: 0)
        self.view.addSubview(collectionView)
        collectionView.register(TZPhotoPreviewCell.self, forCellWithReuseIdentifier: "TZPhotoPreviewCell")
        collectionView.register(TZVideoPreviewCell.self, forCellWithReuseIdentifier: "TZVideoPreviewCell")
        collectionView.register(TZGifPreviewCell.self, forCellWithReuseIdentifier: "TZGifPreviewCell")
    }
    
    private func configCropView() {
        guard let tzImagePickerVc = self.navigationController as? TZImagePickerController else { return }
        if tzImagePickerVc.maxImagesCount <= 1 && tzImagePickerVc.allowCrop && tzImagePickerVc.allowPickingImage {
            cropView.removeFromSuperview()
            cropBgView.removeFromSuperview()
            
            cropBgView = UIView.init(frame: self.view.bounds)
            cropBgView.isUserInteractionEnabled = false
            cropBgView.backgroundColor = .clear
            self.view.addSubview(cropBgView)
            
            TZImageCropManager.overlayClipping(with: cropBgView, cropRect: tzImagePickerVc.cropRect, containerView: self.view, needCircleCrop: tzImagePickerVc.needCircleCrop)
            
            cropView = UIView.init(frame: tzImagePickerVc.cropRect)
            cropView.isUserInteractionEnabled = false
            cropView.backgroundColor = .clear
            cropView.layer.borderColor = UIColor.white.cgColor
            cropView.layer.borderWidth = 1.0
            
            if tzImagePickerVc.needCircleCrop {
                cropView.layer.cornerRadius = tzImagePickerVc.cropRect.size.width / 2
                cropView.clipsToBounds = true
            }
            self.view.addSubview(cropView)
            tzImagePickerVc.cropViewSettingClosure?(cropView)
            
            self.view.bringSubviewToFront(naviBar)
            self.view.bringSubviewToFront(toolBar)
        }
    }
    
    @objc func doneButtonClick() {
        guard let tzImagePickerVc = self.navigationController as? TZImagePickerController else { return }
        if progress > 0 && progress < 1 && (selectButton.isSelected || tzImagePickerVc.selectedModels.isEmpty == true) {
            alertView = tzImagePickerVc.showAlertWithTitle(title: Bundle.tz_localizedString(for: "Synchronizing photos from iCloud"))
            return
        }
        
        if tzImagePickerVc.selectedModels.count == 0 && tzImagePickerVc.minImagesCount <= 0 {
            let model: TZAssetModel = models[self.currentIndex]
            tzImagePickerVc.addSelectedModel(with: model)
        }
        
        let indexPath: IndexPath = IndexPath(item: self.currentIndex, section: 0)
        if let cell: TZPhotoPreviewCell = collectionView.cellForItem(at: indexPath) as? TZPhotoPreviewCell,
            tzImagePickerVc.allowCrop {
            doneButton.isEnabled = false
            tzImagePickerVc.showProgressHUD()
            
            if let previewView = cell.previewView,let imageView = previewView.imageView, var cropedImage: UIImage = TZImageCropManager.cropImageView(imageView, to: tzImagePickerVc.cropRect, to: previewView.scrollView.zoomScale, from: self.view) {
                if tzImagePickerVc.needCircleCrop, let circulImage = TZImageCropManager.circularClipImage(cropedImage) {
                    cropedImage = circulImage
                }
                doneButton.isEnabled = true
                tzImagePickerVc.hideProgressHUD()
                self.doneButtonClickClosureCropMode?(cropedImage, models[self.currentIndex].asset)
            }
            
        } else if self.doneButtonClickClosure != nil {
            self.doneButtonClickClosure?(isSelectOriginalPhoto)
        }
        self.doneButtonClickClosureWithPreviewType?(self.photos ?? [], tzImagePickerVc.selectedAssets, self.isSelectOriginalPhoto)
    }
    
    @objc func originalPhotoButtonClick(_ sender: UIButton) {
        sender.isSelected = !sender.isSelected
        isSelectOriginalPhoto = sender.isSelected
        originalPhotoLabel.isHidden = !sender.isSelected
        if (isSelectOriginalPhoto) {
            self.showPhotoBytes()
            if (!selectButton.isSelected) {
                // 如果当前已选择照片张数 < 最大可选张数 && 最大可选张数大于1，就选中该张图
                if let _tzImagePickerVc = self.navigationController as? TZImagePickerController,_tzImagePickerVc.selectedModels.count < _tzImagePickerVc.maxImagesCount && _tzImagePickerVc.showSelectBtn {
                    self.selectButtonClick(selectButton)
                }
            }
        }
    }
    
    private func didTapPreviewCell() {
        self.isHideNavibar = !self.isHideNavibar
        naviBar.isHidden = self.isHideNavibar
        toolBar.isHidden = self.isHideNavibar
    }
    
    @objc func backButtonClick() {
        if self.navigationController?.children.count ?? 0 < 2 {
            self.navigationController?.dismiss(animated: true, completion: nil)
            if let tzImagePickerVc = self.navigationController as? TZImagePickerController {
                tzImagePickerVc.imagePickerControllerDidCancelClosure?()
            }
            return
        }
        self.navigationController?.popViewController(animated: true)
        self.backButtonClickClosure?(isSelectOriginalPhoto)
    }
    
    @objc func selectButtonClick(_ sender: UIButton) {
        guard let tzImagePickerVc = self.navigationController as? TZImagePickerController else { return }
        var model: TZAssetModel = models[self.currentIndex]
        if !selectButton.isSelected {
            // 1. select:check if over the maxImagesCount / 选择照片,检查是否超过了最大个数的限制
            if tzImagePickerVc.selectedModels.count >= tzImagePickerVc.maxImagesCount {
                tzImagePickerVc.showAlertWithTitle(title: String(format: Bundle.tz_localizedString(for: "Select a maximum of %zd photos"), tzImagePickerVc.maxImagesCount))
                return
            } else {
                tzImagePickerVc.addSelectedModel(with: model)
                if self.photos?.isEmpty == false {
                    tzImagePickerVc.selectedAssets.append(assetsTemp[self.currentIndex])
                    self.photos?.append(photosTemp[self.currentIndex])
                }
                if model.type == .TZAssetModelMediaTypeVideo && !tzImagePickerVc.allowPickingMultipleVideo {
                    tzImagePickerVc.showAlertWithTitle(title: String(format: Bundle.tz_localizedString(for: "Select the video when in multi state, we will handle the video as a photo")))
                }
            }
        } else {
            let selectedModels: [TZAssetModel] = tzImagePickerVc.selectedModels
            for model_item in selectedModels {
                if model.asset.localIdentifier == model_item.asset.localIdentifier {
                    let selectedModelsTmp = tzImagePickerVc.selectedModels
                    for tmp in selectedModelsTmp {
                        if model == tmp {
                            tzImagePickerVc.removeSelectedModel(with: model)
                            break
                        }
                    }
                    
                    if self.photos?.isEmpty == false {
                        let selectedAssetsTmp = tzImagePickerVc.selectedAssets
                        for (index,tmp) in selectedAssetsTmp.enumerated() {
                            if tmp == assetsTemp[self.currentIndex] {
                                tzImagePickerVc.selectedAssets.remove(at: index)
                                break
                            }
                        }
                        
                        self.photos?.removeAll(where: { (image) -> Bool in
                            image == photosTemp[self.currentIndex]
                        })
                    }
                    break
                }
            }
        }
        
        model.isSelected = !selectButton.isSelected
        self.refreshNaviBarAndBottomBarState()
        if model.isSelected {
            UIView.showOscillatoryAnimationWith(layer: selectButton.imageView?.layer, type: .TZOscillatoryAnimationToBigger)
        }
        UIView.showOscillatoryAnimationWith(layer: numberImageView.layer, type: .TZOscillatoryAnimationToSmaller)
    }
    
    private func showPhotoBytes() {
        TZImageManager.manager.getPhotosBytes(withArray: [models[self.currentIndex]]) { [weak self] (totalBytes) in
            self?.originalPhotoLabel.text = "(\(totalBytes))"
        }
    }
    
    
    
    private func refreshNaviBarAndBottomBarState() {
        guard let tzImagePickerVc = self.navigationController as? TZImagePickerController else { return }
        let model = models[self.currentIndex]
        selectButton.isSelected = model.isSelected
        self.refreshSelectButtonImageViewContentMode()
        if selectButton.isSelected && tzImagePickerVc.showSelectedIndex && tzImagePickerVc.showSelectBtn {
            indexLabel.text = String(format: "%d", (tzImagePickerVc.selectedAssetIds.index(of: model.asset.localIdentifier) ?? 0) + 1)
            indexLabel.isHidden = false
        } else {
            indexLabel.isHidden = true
        }
        
        numberLabel.text = String(format: "%zd", tzImagePickerVc.selectedModels.count)
        numberImageView.isHidden = tzImagePickerVc.selectedModels.count <= 0 || isHideNavibar || isCropImage
        numberLabel.isHidden = tzImagePickerVc.selectedModels.count <= 0 || isHideNavibar || isCropImage
        
        originalPhotoButton.isSelected = isSelectOriginalPhoto
        originalPhotoLabel.isHidden = !originalPhotoButton.isSelected
        if isSelectOriginalPhoto {
            self.showPhotoBytes()
        }
        
        if !isHideNavibar {
            if model.type == .TZAssetModelMediaTypeVideo {
                originalPhotoButton.isHidden = true
                originalPhotoLabel.isHidden = true
            } else {
                originalPhotoButton.isHidden = false
                if isSelectOriginalPhoto {
                    originalPhotoLabel.isHidden = false
                }
            }
        }
        
        doneButton.isHidden = false
        selectButton.isHidden = !tzImagePickerVc.showSelectBtn
        if TZImageManager.manager.isPhotoSelectable(with: model.asset) == false {
            numberLabel.isHidden = true
            numberImageView.isHidden = true
            selectButton.isHidden = true
            originalPhotoButton.isHidden = true
            originalPhotoLabel.isHidden = true
            doneButton.isHidden = true
        }
    }
    
    private func refreshSelectButtonImageViewContentMode() {
        DispatchQueue.main.async {
            if self.selectButton.imageView?.image?.size.width ?? 0 <= CGFloat(27.0) {
                self.selectButton.imageView?.contentMode = .center
            } else {
                self.selectButton.imageView?.contentMode = .scaleAspectFit
            }
        }
    }
    
    @objc func didChangeStatusBarOrientationNotification(_ notification: Notification) -> Void {
        offsetItemCount = collectionView.contentOffset.x / layout.itemSize.width
    }
    
    convenience init(with modelArray: [TZAssetModel]) {
        self.init()
        self.models = modelArray
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

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
