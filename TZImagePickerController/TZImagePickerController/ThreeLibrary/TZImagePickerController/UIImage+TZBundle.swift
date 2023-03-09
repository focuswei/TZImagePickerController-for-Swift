//
//  UIImage+TZBundle.swift
//  TZImagePickerController
//
//  Created by FocusWei on 2019/11/13.
//  Copyright © 2019 FocusWei. All rights reserved.
//

import UIKit


extension UIImage {
    
    // only return 2x png
    static func tz_imageNamedFromMyBundle(name: String) -> UIImage? {
        let imgBundle = Bundle.tz_imagePickerBundle()
        var imgName = name
        imgName.append(contentsOf: "@2x.png")
        
        if let imgPath = imgBundle.path(forResource: imgName, ofType: nil),
            let image = UIImage(contentsOfFile: imgPath) {
            return image
        }
        return nil
    }
}
