//
//  TZAlbumPickerController.swift
//  TZImagePickerController
//
//  Created by FocusWei on 2019/11/26.
//  Copyright © 2019 FocusWei. All rights reserved.
//

import UIKit
import Photos

class TZAlbumPickerController: UIViewController,UITableViewDataSource,UITableViewDelegate, PHPhotoLibraryChangeObserver {

    var columnNumber: Int = 0
    var isFirstAppear: Bool = false
    private var tableView: UITableView?
    private var albumArr: [TZAlbumModel] = []
    
    init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        PHPhotoLibrary.shared().register(self)
        self.isFirstAppear = true
        if #available(iOS 13.0, *) {
            view.backgroundColor = .tertiarySystemBackground
        } else {
            view.backgroundColor = UIColor.white
        }
        if let imagePickerVc = self.navigationController as? TZImagePickerController {
            let cancelButton = UIBarButtonItem.init(title: imagePickerVc.cancelBtnTitleStr, style: .plain, target: imagePickerVc, action: #selector(imagePickerVc.cancelButtonClick))
            TZCommonTools.configBarButtonItem(cancelButton, imagePickerVc)
            self.navigationItem.rightBarButtonItem = cancelButton
            
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if let imagePickerVc = self.navigationController as? TZImagePickerController {
            imagePickerVc.hideProgressHUD()
            if imagePickerVc.allowPickingImage {
                self.navigationItem.title = Bundle.tz_localizedString(for: "Photos")
            } else if imagePickerVc.allowPickingVideo {
                self.navigationItem.title = Bundle.tz_localizedString(for: "Videos")
            }
            
            if self.isFirstAppear && imagePickerVc.navLeftBarButtonSettingClosure == nil {
                self.navigationItem.backBarButtonItem = UIBarButtonItem.init(title: Bundle.tz_localizedString(for: "Back"), style: .plain, target: nil, action: nil)
            }
        }
        self.configTableView()
    }
    
    func configTableView() {
        guard TZImageManager.manager.authorizationStatusAuthorized() == true,
            let imagePickerVc = self.navigationController as? TZImagePickerController else {
                return
        }
        
        
        if self.isFirstAppear {
            imagePickerVc.showProgressHUD()
        }
        
        DispatchQueue.global().async {
            TZImageManager.manager.getAllAlbums(allowPickingVideo: imagePickerVc.allowPickingVideo, allowPickingImage: imagePickerVc.allowPickingImage, needFetchAssets: !self.isFirstAppear) { [weak self] (models) in
                self?.albumArr = models
                self?.albumArr.map({
                    $0.selectedModels = imagePickerVc.selectedModels ?? []
                })
                
                DispatchQueue.main.async {
                    imagePickerVc.hideProgressHUD()
                    
                    if self?.isFirstAppear == true {
                        self?.isFirstAppear = false
                        self?.configTableView()
                    }
                    
                    guard let stongSelf = self else { return }
                    if self?.tableView == nil {
                        self?.tableView = UITableView.init(frame: .zero, style: .plain)
                        self?.tableView?.rowHeight = 90
                        self?.tableView?.tableFooterView = UIView()
                        self?.tableView?.dataSource = self
                        self?.tableView?.delegate = self
                        self?.tableView?.separatorInset = UIEdgeInsets.zero
                        self?.tableView?.register(TZAlbumCell.self, forCellReuseIdentifier: "TZAlbumCell")
                        self?.view.addSubview(stongSelf.tableView!)
                    } else {
                        self?.tableView?.reloadData()
                    }
                }
                
                
            }
        }
        
    }
    
    func preferredStatusBarStyle() -> UIStatusBarStyle {
        if let tzImagePicker = self.navigationController as? TZImagePickerController {
            return tzImagePicker.statusBarStyle
        }
        
        return super.preferredStatusBarStyle
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        var top: CGFloat = 0
        var tableViewHeight: CGFloat = 0
        let naviBarHeight = self.navigationController?.navigationBar.tz_height ?? 0.0
        let isStatusBarHidden = TZCommonTools.isStatusBarHidden()
        let isFullScreen: Bool = self.view.tz_height == UIScreen.main.bounds.size.height
        if self.navigationController?.navigationBar.isTranslucent == true {
            top = naviBarHeight
            if isStatusBarHidden == false && isFullScreen {
                top += CGFloat(TZCommonTools.tz_statusBarHeight())
            }
            tableViewHeight = self.view.tz_height - top
        } else {
            tableViewHeight = self.view.tz_height
        }
        self.tableView?.frame = CGRect(x: 0, y: top, width: self.view.tz_width, height: tableViewHeight)
    }
    
    //MARK: ** PHPhotoLibraryChangeObserver **
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        DispatchQueue.main.async {
            self.configTableView()
        }
    }

    //MARK: TableViewDelegate
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.albumArr.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "TZAlbumCell", for: indexPath) as? TZAlbumCell else {
            fatalError()
        }
        if indexPath.row < self.albumArr.count {
            cell.model = self.albumArr[indexPath.row]
        }
        cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
        if let imagePickerVc = self.navigationController as? TZImagePickerController {
            cell.selectedCountButton.backgroundColor = imagePickerVc.iconThemeColor
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let photoPickerVc = TZPhotoPickerController()
        photoPickerVc.columnNumber = self.columnNumber
        if albumArr.count > indexPath.row {
            photoPickerVc.model = albumArr[indexPath.row]
        }
        self.navigationController?.pushViewController(photoPickerVc, animated: true)
        tableView.deselectRow(at: indexPath, animated: false)
    }
}
