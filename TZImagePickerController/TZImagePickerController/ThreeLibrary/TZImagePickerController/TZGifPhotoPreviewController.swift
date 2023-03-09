//
//  TZGifPhotoPreviewController.swift
//  TZImagePickerController
//
//  Created by FocusWei on 2019/12/3.
//  Copyright © 2019 FocusWei. All rights reserved.
//

import UIKit

class TZGifPhotoPreviewController: UIViewController {

    var model: TZAssetModel
    
    private var toolBar: UIView = UIView.init(frame: .zero)
    private var doneButton: UIButton = UIButton.init(type: .custom)
    private var progress: UIProgressView?
    private var previewView: TZPhotoPreviewView = TZPhotoPreviewView.init(frame: .zero)
    private var originStatusBarStyle: UIStatusBarStyle = TZCommonTools.getStatusBarStyle()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.backgroundColor = .black
        if let tzImagePickerVc = self.navigationController as? TZImagePickerController {
            self.navigationItem.title = String(format: "GIF%@", tzImagePickerVc.previewBtnTitleStr)
        }
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    func configPreviewView() {
        previewView.model = self.model
        previewView.singleTapGestureClosure = { [weak self] in
            self?.signleTapAction()
        }
        self.view.addSubview(previewView)
    }
    
    func configBottomToolBar() {
        
        toolBar.backgroundColor = UIColor.toolBarBgColor
        
        doneButton.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        doneButton.addTarget(self, action: #selector(doneButtonClick), for: .touchUpInside)
        if let tzImagePickerVc = self.navigationController as? TZImagePickerController {
            doneButton.setTitle(tzImagePickerVc.doneBtnTitleStr, for: .normal)
            doneButton.setTitleColor(TZImagePickerController.oKButtonTitleColorNormal, for: .normal)
        } else {
            doneButton.setTitle(Bundle.tz_localizedString(for: "Done"), for: .normal)
            doneButton.setTitleColor(TZImagePickerController.oKButtonTitleColorNormal, for: .normal)
        }
        toolBar.addSubview(doneButton)
        
        let byteLabel = UILabel.init(frame: .zero)
        byteLabel.textColor = .white
        byteLabel.font = UIFont.systemFont(ofSize: 13.0)
        byteLabel.frame = CGRect(x: 10, y: 0, width: 100, height: 44)
        TZImageManager.manager.getPhotosBytes(withArray: [model]) { (totalBytes) in
            byteLabel.text = totalBytes
        }
        toolBar.addSubview(byteLabel)
        
        self.view.addSubview(toolBar)
        
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        previewView.frame = self.view.bounds
        previewView.scrollView.frame = self.view.bounds
        let toolBarHeight: CGFloat = 44 + TZCommonTools.tz_safeAreaInsets().bottom
        toolBar.frame = CGRect(x: 0, y: self.view.tz_height - toolBarHeight, width: self.view.tz_width, height: toolBarHeight)
        doneButton.frame = CGRect(x: self.view.tz_width - 44 - 12, y: 0, width: 44, height: 44)
    }
    
    @objc func doneButtonClick() {
        if let tzImagePickerVc = self.navigationController as? TZImagePickerController {
            if tzImagePickerVc.autoDismiss {
                self.navigationController?.dismiss(animated: true, completion: {
                    self.callDelegateMethod()
                })
            } else {
                self.callDelegateMethod()
            }
        } else {
            dismiss(animated: true, completion: {
                self.callDelegateMethod()
            })
        }
    }
    
    @objc func signleTapAction() {
        toolBar.isHidden = !toolBar.isHidden
        self.navigationController?.setNavigationBarHidden(toolBar.isHidden, animated: true)
        
        if toolBar.isHidden {
            UIApplication.shared.isStatusBarHidden = true
        } else if let tzImagePickerVc = self.navigationController as? TZImagePickerController, tzImagePickerVc.needShowStatusBar {
            UIApplication.shared.isStatusBarHidden = false
        }
    }
    
    
    
    private func callDelegateMethod() {
        
        if let tzImagePickerVc = self.navigationController as? TZImagePickerController,let animatedImage = previewView.imageView?.image {
            tzImagePickerVc.pickerDelegate?.imagePickerController?(picker: tzImagePickerVc, didFinishPickingGifImage: animatedImage, sourceAssets: model.asset)
            
            tzImagePickerVc.didFinishPickingGifImageClosure?(animatedImage, [model.asset])
        }
        
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        
        if let tzImagePickerVc = self.navigationController as? TZImagePickerController {
            return tzImagePickerVc.statusBarStyle
        }
        return super.preferredStatusBarStyle
    }
    
    init(with assetModel: TZAssetModel) {
        model = assetModel
        super.init(nibName: nil, bundle: nil)
        self.configPreviewView()
        self.configBottomToolBar()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
