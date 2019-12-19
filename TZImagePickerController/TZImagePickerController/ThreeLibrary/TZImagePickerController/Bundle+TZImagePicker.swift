//
//  NSBundle+TZImagePicker.swift
//  TZImagePickerController
//
//  Created by FocusWei on 2019/11/12.
//  Copyright © 2019 FocusWei. All rights reserved.
//

import UIKit

extension Bundle {
    static func tz_imagePickerBundle() -> Bundle {
        let bundle: Bundle = Bundle.init(for: TZImagePickerController.self)
        if let imageUrl = bundle.url(forResource: "TZImagePickerController", withExtension: "bundle"),
            let urlBundle = Bundle.init(url: imageUrl) {
            return urlBundle
        }
        return bundle
    }
    
    static func tz_localizedString(for key:String) -> String {
        return Bundle.tz_localizedString(for: key, value: nil)
    }
    
    static func tz_localizedString(for key: String, value: String?) -> String {
        let bundle :Bundle? = TZImagePickerConfig.sharedInstance.languageBundle
        let value1 = bundle?.localizedString(forKey: key, value: value, table: nil)
        return value1 ?? ""
    }
    

}
