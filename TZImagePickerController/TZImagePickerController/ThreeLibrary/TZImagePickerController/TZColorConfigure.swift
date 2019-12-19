//
//  TZColorConfigure.swift
//  TZImagePickerController
//
//  Created by FocusWei on 2019/12/16.
//  Copyright © 2019 FocusWei. All rights reserved.
//

import UIKit

extension UIColor {
    convenience init(hexColor: UInt32, alpha: CGFloat) {
        let red = CGFloat((hexColor & 0xFF0000) >> 16) / 255.0
        let green = CGFloat((hexColor & 0x00FF00) >> 8) / 255.0
        let blue = CGFloat((hexColor & 0x0000FF)) / 255.0
        self.init(red: red, green: green, blue: blue, alpha: alpha)
        if #available(iOS 10.0, *) {
//            self.init(displayP3Red: CGFloat(red) / 255, green: CGFloat(green) / 255, blue: CGFloat(blue) / 255, alpha: alpha)
        }
    }
    
    convenience init(hexColor: UInt32) {
        self.init(hexColor: hexColor, alpha: 1.0)
    }
    
    // aplus color
    static var bottomViewBgColor :         UIColor { return UIColor.init(red: 0, green: 0, blue: 0, alpha: 0.8) }
    static var noDataLabelTextColor:        UIColor {
        let rgb: CGFloat = 153/255.0
        return UIColor.init(red: rgb, green: rgb, blue: rgb, alpha: 1)
    }
    static var toolBarBgColor:      UIColor {
        //navigationBar.barTintColor
        let rgb: CGFloat = 34/255.0
        return UIColor.init(red: rgb, green: rgb, blue: rgb, alpha: 0.7)
    }
    static var iconThemeColor :        UIColor { return UIColor.init(red: 31/255.0, green: 185/255.0, blue: 34/255.0, alpha: 1.0) }
    static var doneButtonTitleColor :      UIColor { return UIColor.init(red: 31/255.0, green: 185/255.0, blue: 34/255.0, alpha: 1.0) }

}
