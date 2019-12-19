//
//  ViewController.swift
//  TZImagePickerController
//
//  Created by FocusWei on 2019/11/12.
//  Copyright © 2019 FocusWei. All rights reserved.
//

import UIKit
import Photos.PHAsset

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, LxGridViewDataSource, LxGridViewDelegateFlowLayout {
    
    @IBOutlet weak var scrollView: UIScrollView!
    
    
    @IBOutlet weak var showTakePhotoBtnSwitch: UISwitch!
    @IBOutlet weak var sortAscendingSwitch: UISwitch!
    @IBOutlet weak var allowPickingVideoSwitch: UISwitch!
    @IBOutlet weak var allowPickingImageSwitch: UISwitch!
    @IBOutlet weak var allowPickingGifSwitch: UISwitch!
    @IBOutlet weak var allowPickingOriginalPhotoSwitch: UISwitch!
    @IBOutlet weak var showSheetSwitch: UISwitch!
    @IBOutlet weak var maxCountTF: UITextField!
    @IBOutlet weak var columnNumberTF: UITextField!
    @IBOutlet weak var allowCropSwitch: UISwitch!
    @IBOutlet weak var needCircleCropSwitch: UISwitch!
    @IBOutlet weak var allowPickingMuitlpleVideoSwitch: UISwitch!
    @IBOutlet weak var showSelectedIndexSwitch: UISwitch!
    @IBOutlet weak var showTakeVideoBtnSwitch: UISwitch!
    
    
    
    var _isSelectOriginalPhoto: Bool = false

    var _itemWH: CGFloat = 0
    var _margin: CGFloat = 0

    var layout: LxGridViewFlowLayout?
    var location: CLLocation?

    //MARK: -
    lazy var collectionView: UICollectionView = {
        let margin: CGFloat = 4

        let width = view.frame.width - 2 * margin - 4
        var itemWH: CGFloat = width / 3 - margin
        let flowlayout = UICollectionViewFlowLayout()
        flowlayout.itemSize = CGSize(width: itemWH, height: itemWH)
        flowlayout.minimumInteritemSpacing = margin
        flowlayout.minimumLineSpacing = margin
        let collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: flowlayout)
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.backgroundColor = UIColor(red: 244 / 255.0, green: 244 / 255.0, blue: 244 / 255.0, alpha: 1)

        collectionView.register(TZTestCell.classForCoder(), forCellWithReuseIdentifier: "TZTestCell")
        return collectionView
    }()

    lazy var imagePickerVC: UIImagePickerController = {
        let imagePickerVC = UIImagePickerController()
        imagePickerVC.delegate = self
        imagePickerVC.navigationBar.barTintColor = self.navigationController?.navigationBar.barTintColor
        imagePickerVC.navigationBar.tintColor = self.navigationController?.navigationBar.tintColor
        let tzBarItem: UIBarButtonItem?, BarItem: UIBarButtonItem?
        if #available(iOS 9.0, *) {
            tzBarItem = UIBarButtonItem.appearance(whenContainedInInstancesOf: [TZImagePickerController.classForCoder() as! UIAppearanceContainer.Type])
            BarItem = UIBarButtonItem.appearance(whenContainedInInstancesOf: [UIImagePickerController.classForCoder() as! UIAppearanceContainer.Type])
        } else {
            tzBarItem = UIBarButtonItem.appearance()
            BarItem = UIBarButtonItem.appearance()
        }
        let titleTextAttributes = tzBarItem?.titleTextAttributes(for: .normal)
        BarItem?.setTitleTextAttributes(titleTextAttributes ?? nil, for: .normal)
        return imagePickerVC
    }()



    var selectedPhotos = [UIImage]()
    var selectedAssets = [PHAsset]()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.white

        configCollectionView()

    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let contentSizeH: CGFloat = 12 * 35 + 20
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.01) {
            self.scrollView.contentSize = CGSize(width: 0, height: contentSizeH + 5)
        }
        let width = self.view.frame.width - 2 * _margin - 4
        _margin = 4
        _itemWH = width / 3 - _margin
        layout?.itemSize = CGSize(width: _itemWH, height: _itemWH)
        layout?.minimumInteritemSpacing = _margin
        layout?.minimumLineSpacing = _margin
        self.collectionView.setCollectionViewLayout(layout!, animated: false)
        self.collectionView.frame = CGRect(x: 0, y: self.scrollView.frame.maxY, width: self.view.frame.width, height: self.view.frame.height - self.scrollView.frame.maxY)
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func configCollectionView() {
        // 如不需要长按排序效果，将LxGridViewFlowLayout类改成UICollectionViewFlowLayout即可
        layout = LxGridViewFlowLayout()
        collectionView = UICollectionView(frame: CGRect.zero, collectionViewLayout: layout!)
        collectionView.alwaysBounceVertical = true
        collectionView.backgroundColor = UIColor(red: 244 / 255.0, green: 244 / 255.0, blue: 244 / 255.0, alpha: 1)

        collectionView.contentInset = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4);
        collectionView.dataSource = self;
        collectionView.delegate = self;
        collectionView.keyboardDismissMode = .onDrag
        self.view.addSubview(collectionView)
        collectionView.register(TZTestCell.classForCoder(), forCellWithReuseIdentifier: "TZTestCell")
        self.collectionView.frame = CGRect(x: 0, y: self.scrollView.frame.maxY, width: self.view.frame.width, height: self.view.frame.height - self.scrollView.frame.maxY)
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if selectedPhotos.count >= Int(self.maxCountTF.text ?? "0")! {
            return selectedPhotos.count
        }
        if self.allowPickingMuitlpleVideoSwitch.isOn == false {
            for asset in selectedAssets {
                if asset.mediaType == .video {
                    return selectedPhotos.count
                }
            }
        }
        return self.selectedPhotos.count + 1
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "TZTestCell", for: indexPath) as! TZTestCell
        cell.videoImageView?.isHidden = true
        if indexPath.row == selectedPhotos.count {
            let image = UIImage(named: "AlbumAddBtn")
            cell.imageView?.image = image
            cell.deleteBtn?.isHidden = true;
            cell.gifLable?.isHidden = true;
        } else {
            cell.imageView?.image = selectedPhotos[indexPath.row];
            cell.asset = selectedAssets[indexPath.row];
            cell.deleteBtn?.isHidden = false;
        }
        if (!self.allowPickingGifSwitch.isOn) {
            cell.gifLable?.isHidden = true;
        }
        cell.deleteBtn?.tag = indexPath.row;
        cell.deleteBtn?.addTarget(self, action: #selector(deleteBtnClick(_:)), for: .touchUpInside)
        return cell;
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath.row == selectedPhotos.count {
            let showSheet = self.showSheetSwitch.isOn
            if (showSheet) {
                let alertVC = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
                alertVC.addAction(UIAlertAction(title: "拍照", style: .default, handler: { (action) in
                    self.takePhoto()
                }))
                alertVC.addAction(UIAlertAction(title: "去相册选择", style: .default, handler: { (action) in
                    self.pushTZImagePickerController()
                }))
                alertVC.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))
                self.present(alertVC, animated: true, completion: nil)
            } else {
                self.pushTZImagePickerController()
            }
        } else {
            let asset = selectedAssets[indexPath.item]
            let isVideo = asset.mediaType == .video
            var isGif = false
            if #available(iOS 11, *),asset.playbackStyle == .imageAnimated {
                isGif = true
            }
            if isGif && self.allowPickingMuitlpleVideoSwitch.isOn {
                let gifPhotoVc = TZGifPhotoPreviewController.init(with: TZAssetModel.init(asset: asset, type: .TZAssetModelMediaTypePhotoGif)
                )
                gifPhotoVc.modalPresentationStyle = .fullScreen
                self.present(gifPhotoVc, animated: true, completion: nil)
            } else if isVideo && self.allowPickingMuitlpleVideoSwitch.isOn == false {
                let videoPlayerVc = TZVideoPlayerController.init()
                videoPlayerVc.model = TZAssetModel.init(asset: asset, type: .TZAssetModelMediaTypeVideo)
                videoPlayerVc.modalPresentationStyle = .fullScreen
                self.present(videoPlayerVc, animated: true, completion: nil)
            } else {
                let imagePickerVc = TZImagePickerController.init(with: selectedAssets, selectedPhotos: selectedPhotos, index: indexPath.item)
                imagePickerVc.maxImagesCount = Int(self.maxCountTF.text ?? "0")!
                imagePickerVc.allowPickingGif = self.allowPickingGifSwitch.isOn
                imagePickerVc.allowPickingOriginalPhoto = self.allowPickingOriginalPhotoSwitch.isOn
                imagePickerVc.allowPickingMultipleVideo = self.allowPickingMuitlpleVideoSwitch.isOn
                imagePickerVc.showSelectedIndex = self.showSelectedIndexSwitch.isOn
                imagePickerVc.isSelectOriginalPhoto = _isSelectOriginalPhoto
                imagePickerVc.modalPresentationStyle = .fullScreen
                imagePickerVc.didFinishPickingPhotosClosure = { [weak self] (photos, assets, isSelectOriginalPhoto) in
                    self?.selectedPhotos = photos
                    self?.selectedAssets = assets
                    self?._isSelectOriginalPhoto = isSelectOriginalPhoto
                    self?.collectionView.reloadData()
//                    let height = CGFloat(self?.selectedPhotos.count! + 2) / 3.0 * (self?._margin + self?._itemWH)
//                    self?.collectionView.contentSize = CGSize(width: 0, height: height)
                }
                self.present(imagePickerVc, animated: true, completion: nil)
            }
        }
    }

    func pushTZImagePickerController() {
        guard let maxCount = Int(self.maxCountTF.text ?? ""), let columnNumber = Int(self.columnNumberTF.text ?? "") else { return }
        let imagePickerVc: TZImagePickerController = TZImagePickerController.init(take: maxCount, columnNumber: columnNumber, delegate: self, pushPhotoPickerVc: true)
        
        /**
         下面是可选内容 五类个性化设置，这些参数都可以不传，此时会走默认设置
         */
        imagePickerVc.isSelectOriginalPhoto = _isSelectOriginalPhoto
        
        imagePickerVc.allowTakePicture = self.showTakePhotoBtnSwitch.isOn
        imagePickerVc.allowPickingVideo = self.allowPickingVideoSwitch.isOn
        imagePickerVc.videoMaximumDuration = 10
        imagePickerVc.uiImagePickerControllerSettingClosure = { (imagePickerController) in
            imagePickerController.videoQuality = .typeHigh
        }
        
        imagePickerVc.didFinishPickingPhotosClosure = { (photos, assets, isSelectOriginalPhoto) in
            debugPrint(photos)
        }
        
        
            // 1.设置目前已经选中的图片数组
//            imagePickerVc.selectedAssets =  // 目前已经选中的图片数组
        
        // imagePickerVc.photoWidth = 1000;
        
        // 2. Set the appearance
        // 2. 在这里设置imagePickerVc的外观
        
        
        // 3. Set allow picking video & photo & originalPhoto or not
        // 3. 设置是否可以选择视频/图片/原图
        imagePickerVc.allowPickingVideo = self.allowPickingVideoSwitch.isOn
        imagePickerVc.allowPickingImage = self.allowPickingImageSwitch.isOn
        imagePickerVc.allowPickingOriginalPhoto = self.allowPickingOriginalPhotoSwitch.isOn
        imagePickerVc.allowPickingGif = self.allowPickingGifSwitch.isOn
        imagePickerVc.allowPickingMultipleVideo = self.allowPickingMuitlpleVideoSwitch.isOn // 是否可以多选视频
        
        // 4. 照片排列按修改时间升序
        imagePickerVc.sortAscendingByModificationDate = self.sortAscendingSwitch.isOn

        
        /// 5. Single selection mode, valid when maxImagesCount = 1
        /// 5. 单选模式,maxImagesCount为1时才生效
        imagePickerVc.showSelectBtn = false
        imagePickerVc.allowCrop = self.allowCropSwitch.isOn
        imagePickerVc.needCircleCrop = self.needCircleCropSwitch.isOn
        // 设置竖屏下的裁剪尺寸
//        let left: CGFloat = 30;
//        let widthHeight: CGFloat = self.view.frame.width - 2 * left
//        let top: CGFloat = (self.view.frame.height - widthHeight) / 2
//        imagePickerVc.cropRect = CGRect(x: left, y: top, width: widthHeight, height: widthHeight)
        // 设置横屏下的裁剪尺寸
        // imagePickerVc.cropRectLandscape = CGRectMake((self.view.tz_height - widthHeight) / 2, left, widthHeight, widthHeight);
        /*
         [imagePickerVc setCropViewSettingBlock:^(UIView *cropView) {
         cropView.layer.borderColor = [UIColor redColor].CGColor;
         cropView.layer.borderWidth = 2.0;
         }];*/
        
        //imagePickerVc.allowPreview = NO;
        // 自定义导航栏上的返回按钮
        /*
         [imagePickerVc setNavLeftBarButtonSettingBlock:^(UIButton *leftButton){
         [leftButton setImage:[UIImage imageNamed:@"back"] forState:UIControlStateNormal];
         [leftButton setImageEdgeInsets:UIEdgeInsetsMake(0, -20, 0, 20)];
         }];
         imagePickerVc.delegate = self;
         */
        
        imagePickerVc.statusBarStyle = .lightContent
        // 设置是否显示图片序号
        imagePickerVc.showSelectedIndex = self.showSelectedIndexSwitch.isOn
        
        // 自定义gif播放方案
        TZImagePickerConfig.sharedInstance.gifImagePlayClosure = { (_, imageView, gifData, info) in
            
        }
        //TODO: - 到这里为止
        
        // You can get the photos by block, the same as by delegate.
        // 你可以通过block或者代理，来得到用户选择的照片.
        imagePickerVc.didFinishPickingPhotosWithInfosClosure = { (photos, assets, isSelectOriginalPhoto, infoArr) -> (Void) in
            
            debugPrint("\(photos.count) ---\(assets.count) ---- \(isSelectOriginalPhoto) --- \(String(describing: infoArr))")
        }
        
        
        //MARK: 全屏幕的模态跳转
        imagePickerVc.modalPresentationStyle = UIModalPresentationStyle.fullScreen
        if let rootVc = UIApplication.shared.keyWindow?.rootViewController {
            rootVc.present(imagePickerVc, animated: true, completion: nil)
        }
    }
    
    func takePhoto() {
            let authStatus = AVCaptureDevice.authorizationStatus(for: .video)
            if authStatus == .restricted || authStatus == .denied {
                // 无相机权限 做一个友好的提示
                let alertVC = UIAlertController(title: "无法使用相机", message: "请在iPhone的\"设置-隐私-相机\"中允许访问相机", preferredStyle: .alert)
                alertVC.addAction(UIAlertAction(title: "设置", style: .default, handler: { (action) in
                    UIApplication.shared.openURL(URL(string: UIApplication.openSettingsURLString)!)
                }))
                alertVC.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))
                self.present(alertVC, animated: true, completion: nil)
            } else if authStatus == .notDetermined {
                // fix issue 466, 防止用户首次拍照拒绝授权时相机页黑屏
                AVCaptureDevice.requestAccess(for: .video) { (granted) in
                    if granted {
                        DispatchQueue.main.async {
                            self.takePhoto()
                        }
                    }
                }
                // 拍照之前还需要检查相册权限
            } else {
                pushImagePickerController()
            }
        }
        
        // 调用相机
        func pushImagePickerController() {
            
            //去掉定位
            
            let sourceType = UIImagePickerController.SourceType.camera
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                self.imagePickerVC.sourceType = sourceType
                self.imagePickerVC.modalPresentationStyle = .overCurrentContext
                present(self.imagePickerVC, animated: true, completion: nil)
            } else {
                print("模拟器中无法打开照相机,请在真机中使用")
            }
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            picker.dismiss(animated: true, completion: nil)
            guard let type = info[.mediaType] as? String else { return }
            let tzImagePickerVc = TZImagePickerController.init(take: 1, delegate: self)
            tzImagePickerVc.sortAscendingByModificationDate = self.sortAscendingSwitch.isOn
            tzImagePickerVc.showProgressHUD()
            if type == "public.image" {
                
                guard let image = info[.originalImage] as? UIImage else {
                    tzImagePickerVc.hideProgressHUD()
                    debugPrint("image is nil")
                    return
                }
                // save photo and get asset / 保存图片，获取到asset
                TZImageManager.manager.savePhoto(with: image, callback: { (asset, error) in
                    if let error_save = error {
                        tzImagePickerVc.hideProgressHUD()
                        debugPrint("save error \(error_save.localizedDescription)")
                        return
                    }

                    TZImageManager.manager.getCameraRollAlbum(allowPickingVideo: false, allowPickingImage: true, needFetchAssets: false, callback: { (model) in
                        TZImageManager.manager.getAssets(from: model.result, allowPickingVideo: false, allowPickingImage: true) { (models) -> (Void) in
                            tzImagePickerVc.hideProgressHUD()
                            var assetModel = models.first
                            if tzImagePickerVc.sortAscendingByModificationDate {
                                assetModel = models.last
                            }
                            
                            self.refreshCollectionView((assetModel?.asset)!, image: image)
                            
                        }
                    })
                })
                self.location = nil;
            } else if type == "public.movie" {
                //拍摄视频之后保存
                if let videoUrl = info[UIImagePickerController.InfoKey.mediaURL] as? URL {
                    TZImageManager.manager.saveVideo(with: videoUrl) { (asset, error) in
                        tzImagePickerVc.hideProgressHUD()
                        if error == nil,asset != nil {
                            let assetModel = TZAssetModel.init(asset: asset!, type: TZImageManager.manager.getAssetType(asset: asset!))
                            TZImageManager.manager.getPhoto(with: assetModel.asset) { (photo, _, isDegraded) in
                                if isDegraded == false {
                                    self.refreshCollectionView(assetModel.asset, image: photo)
                                }
                            }
                        }
                    }
                }
            }
        }

        func refreshCollectionView(_ asset: PHAsset, image:UIImage) {
            selectedAssets.append(asset)
            selectedPhotos.append(image)
            collectionView.reloadData()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            if picker.isKind(of: UIImagePickerController.classForCoder()) {
                picker.dismiss(animated: true, completion: nil);
            }
        }

        //MARK: -  click
        @IBAction func showTakePhotoBtnSwitchClick(_ sender: UISwitch) {
            if (sender.isOn) {
                self.allowPickingImageSwitch.setOn(true, animated: true)
            }
        }

        @IBAction func showSheetSwitchClick(_ sender: UISwitch) {
            if (sender.isOn) {
                self.allowPickingImageSwitch.setOn(true, animated: true)
            }
        }

        @IBAction func allowPickingOriginPhotoSwitchClick(_ sender: UISwitch) {
            if (sender.isOn) {
                self.allowPickingImageSwitch.setOn(true, animated: true)
                self.needCircleCropSwitch.setOn(false, animated: true)
                self.allowCropSwitch.setOn(false, animated: true)
            }
        }

        @IBAction func allowPickingImageSwitchClick(_ sender: UISwitch) {
            if (!sender.isOn) {
                self.allowPickingOriginalPhotoSwitch.setOn(false, animated: true)
                self.showTakePhotoBtnSwitch.setOn(false, animated: true)
                self.allowPickingVideoSwitch.setOn(true, animated: true)
                self.allowPickingGifSwitch.setOn(false, animated: true)
            }
        }

        @IBAction func allowPickingGifSwitchClick(_ sender: UISwitch) {
            if sender.isOn {
                self.allowPickingImageSwitch.setOn(true, animated: true)
            } else if !self.allowPickingVideoSwitch.isOn {
                self.allowPickingMuitlpleVideoSwitch.setOn(false, animated: true)
            }
        }

        @IBAction func allowPickingVideoSwitchClick(_ sender: UISwitch) {
            if !sender.isOn {
                self.allowPickingImageSwitch.setOn(true, animated: true)
                if self.allowPickingGifSwitch.isOn == false {
                    self.allowPickingMuitlpleVideoSwitch.setOn(false, animated: true)
                }
            }
        }

        @IBAction func allowCropSwitchClick(_ sender: UISwitch) {
            if (sender.isOn) {
                self.maxCountTF.text = "1";
                self.allowPickingOriginalPhotoSwitch.setOn(false, animated: true)
            } else {
                if self.maxCountTF.text == "1" {
                    self.maxCountTF.text = "9";
                }
                self.needCircleCropSwitch.setOn(false, animated: true)
            }
        }

        @IBAction func needCircleCropSwitchClick(_ sender: UISwitch) {
            if sender.isOn {
                self.allowCropSwitch.setOn(true, animated: true)
                self.maxCountTF.text = "1"
                self.allowPickingOriginalPhotoSwitch.setOn(false, animated: true)
            }
        }

        @IBAction func allowPickingMultipleVideoSwitchClick(_ sender: UISwitch) {
        }


        @objc func deleteBtnClick(_ sender: UIButton) {

            if self.collectionView(self.collectionView, numberOfItemsInSection: 0) <= selectedPhotos.count {
                selectedAssets.remove(at: sender.tag)
                selectedPhotos.remove(at: sender.tag)
                self.collectionView.reloadData()
                return
            }
            selectedAssets.remove(at: sender.tag)
            selectedPhotos.remove(at: sender.tag)

            collectionView.performBatchUpdates({
                let indexPath = IndexPath(item: sender.tag, section: 0)
                self.collectionView.deleteItems(at: [indexPath])
            }) { (finished) in
                self.collectionView.reloadData()
            }
        }

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            super.touchesBegan(touches, with: event)
            view.endEditing(true)
        }

    }


    extension ViewController: TZImagePickerControllerDelegate {
        /// User click cancel button
        /// 取消
        func tz_imagePickerControllerDidCancel(_ picker: TZImagePickerController) {
            print("取消")
        }
        
        // 如果用户选择了一个视频且allowPickingMultipleVideo是NO，下面的代理方法会被执行
        func imagePickerController(picker: TZImagePickerController, didFinishPickingVideo coverImage: UIImage, sourceAssets: PHAsset) {
            selectedPhotos = [coverImage]
            selectedAssets = [sourceAssets]

            TZImageManager.manager.getVideoOutputPath(with: sourceAssets, success: { (outputPath) in
                print("视频导出到本地完成,沙盒路径为:\(outputPath)")
            }, failure: nil)
            collectionView.reloadData()
        }

        // The picker should dismiss itself; when it dismissed these handle will be called.
        // If isOriginalPhoto is YES, user picked the original photo.
        // You can get original photo with asset, by the method [[TZImageManager manager] getOriginalPhotoWithAsset:completion:].
        // The UIImage Object in photos default width is 828px, you can set it by photoWidth property.
        // 这个照片选择器会自己dismiss，当选择器dismiss的时候，会执行下面的代理方法
        // 如果isSelectOriginalPhoto为YES，表明用户选择了原图
        // 你可以通过一个asset获得原图，通过这个方法：[[TZImageManager manager] getOriginalPhotoWithAsset:completion:]
        // photos数组里的UIImage对象，默认是828像素宽，你可以通过设置photoWidth属性的值来改变它
        func imagePickerController(picker: TZImagePickerController, didFinishPick photos: Array<UIImage>, get sourceAssets: Array<PHAsset>, isSelectOriginalPhoto: Bool, infoArray: Array<Dictionary<AnyHashable, Any>>?) {
            selectedPhotos = photos
            selectedAssets = sourceAssets

            _isSelectOriginalPhoto = isSelectOriginalPhoto;
            collectionView.reloadData()
            // _collectionView.contentSize = CGSizeMake(0, ((_selectedPhotos.count + 2) / 3 ) * (_margin + _itemWH));

            // 1.打印图片名字
            _ = sourceAssets.map({
                debugPrint($0.value(forKey: "filename") ?? "没有名字")
            })
            // 2.图片位置信息
            _ = sourceAssets.map({
                debugPrint($0.location ?? "没有位置信息")
            })

        }

        // If user picking a gif image, this callback will be called.
        // 如果用户选择了一个gif图片，下面的handle会被执行
        
        func imagePickerController(picker: TZImagePickerController, didFinishPickingGifImage animatedImage: UIImage, sourceAssets: PHAsset) {
            selectedPhotos.append(animatedImage)
            selectedAssets.append(sourceAssets)
            collectionView.reloadData()
        }
}

