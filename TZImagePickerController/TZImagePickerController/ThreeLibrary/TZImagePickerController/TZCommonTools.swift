//
//  TZCommonTools.swift
//  TZImagePickerController
//
//  Created by FocusWei on 2019/11/26.
//  Copyright © 2019 FocusWei. All rights reserved.
//

import UIKit

class TZCommonTools {
    static func tz_isIPhoneX() -> Bool {
        var size = UIScreen.main.bounds.size
        if size.height < size.width {
            let tmp = size.height
            size.height = size.width
            size.width = tmp
        }
        if Int((size.height/size.width)*100) == 216 {
            return true
        }
        return false
    }
    
    static func tz_getInfoDictionary() -> Dictionary<String, Any> {
        var info: [String:Any] = [:]
        if let infoDict = Bundle.main.localizedInfoDictionary {
            info = infoDict
        } else if let infoDict = Bundle.main.infoDictionary {
            info = infoDict
        } else if let path = Bundle.main.path(forResource: "Info", ofType: "plist"),
            let url = URL(string: path),
            let infoDict = NSDictionary.init(contentsOf: url) as? [String : Any] {
            info = infoDict
        }
        
        return info
    }
    
    static func tz_isRightToLeftLayout() -> Bool {
        if UIView.userInterfaceLayoutDirection(for: UISemanticContentAttribute.unspecified) == UIUserInterfaceLayoutDirection.rightToLeft {
            return true
        }
        return false
    }
    
    
    static func getKeyWindow() -> UIWindow? {
        guard #available(iOS 13.0, *) else  {
            return UIApplication.shared.keyWindow
        }
        
        let keyWindow = UIApplication.shared.windows
            .filter({ $0.isKeyWindow })
            .first
        return keyWindow
    }
    
    static func isStatusBarHidden() -> Bool {
        guard #available(iOS 13.0, *) else {
            return UIApplication.shared.isStatusBarHidden
        }
        
        return  TZCommonTools.getKeyWindow()?.windowScene?.statusBarManager?.isStatusBarHidden ?? false
    }
    
    static func getStatusBarStyle() -> UIStatusBarStyle {
        guard #available(iOS 13.0, *) else {
            return UIApplication.shared.statusBarStyle
        }
        return  TZCommonTools.getKeyWindow()?.windowScene?.statusBarManager?.statusBarStyle ?? UIStatusBarStyle.default
    }
    
    static func tz_statusBarHeight() -> CGFloat {
        //不能用statusBarFrame的原因：If the status bar is hidden, the value of this property is CGRectZero.
        return self.tz_isIPhoneX() ? 44:20
    }
    
    static func configBarButtonItem(_ item: UIBarButtonItem, _ tzImagePickerVc: TZImagePickerController) {
        item.tintColor = tzImagePickerVc.barItemTextColor
        var textAttrs: [NSAttributedString.Key:Any] = [:]
        textAttrs[NSAttributedString.Key.foregroundColor] = tzImagePickerVc.barItemTextColor
        textAttrs[NSAttributedString.Key.font] = tzImagePickerVc.barItemTextFont
        item.setTitleTextAttributes(textAttrs, for: .normal)
    }
}

class TZImagePickerConfig {
    static let sharedInstance = TZImagePickerConfig()
    var preferredLanguage: String? {
        didSet {
            let chinese = "zh-Hans"
            let cantonese = "zh-Hant"
            let vi = "vi"
            let en = "en"
            var pl = self.preferredLanguage
            if (pl == nil) {
                pl = NSLocale.preferredLanguages.first
            }
            if pl?.contains(chinese) == true {
                pl = chinese
            } else if pl?.contains(cantonese) == true {
                pl = cantonese
            } else if pl?.contains(vi) == true {
                pl = vi
            } else if pl?.contains(en) == true {
                pl = en
            }

            let imageBundle: Bundle = Bundle.tz_imagePickerBundle()
            if let path = imageBundle.path(forResource: pl, ofType: ".lproj") {
                self.languageBundle = Bundle(path: path)
            }
            
        }
    }
    var allowPickingImage: Bool = true
    var allowPickingVideo: Bool = false
    var languageBundle: Bundle?
    var showSelectedIndex: Bool = false
    var showPhotoCannotSelectLayer: Bool = false
    var notScaleImage: Bool = false
    var needFixComposition: Bool = false
    
    /// 默认是50，如果一个GIF过大，里面图片个数可能超过1000，会导致内存飙升而崩溃
    var gifPreviewMaxImagesCount: Int = 50
    
    var gifImagePlayClosure: ((_ photoPreviewView: TZPhotoPreviewView, _ imageview: UIImageView?, _ gifData:Data, _ info: Dictionary<AnyHashable,Any>?) -> Void)?
    
    init() {
        defer {
            self.preferredLanguage = nil
        }
    }
}

