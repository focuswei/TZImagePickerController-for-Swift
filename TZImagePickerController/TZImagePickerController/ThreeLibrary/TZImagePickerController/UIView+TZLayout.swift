//
//  UIView+TZLayout.swift
//  TZImagePickerController
//
//  Created by guozw3 on 2019/11/12.
//  Copyright © 2019 centaline. All rights reserved.
//

import UIKit

enum TZOscillatoryAnimationType {
    case TZOscillatoryAnimationToBigger
    case TZOscillatoryAnimationToSmaller
}

extension UIView {
    var tz_left: CGFloat {
        set {
            var frame: CGRect = self.frame
            frame.origin.x = newValue
            self.frame = frame
        }
        get {
            return self.frame.origin.x
        }
    }
    
    var tz_top: CGFloat {
        set {
            var frame: CGRect = self.frame
            frame.origin.y = newValue
            self.frame = frame
        }
        get {
            return self.frame.origin.y
        }
    }
    
    var tz_right: CGFloat {
        set {
            var frame: CGRect = self.frame
            frame.origin.x = newValue - frame.size.width
            self.frame = frame
        }
        get {
            return self.frame.origin.x + self.frame.size.width
        }
    }
    
    var tz_bottom: CGFloat {
        set {
            var frame: CGRect = self.frame
            frame.origin.y = newValue - frame.size.height
            self.frame = frame
        }
        get {
            return self.frame.origin.y + self.frame.size.height
        }
    }
    
    var tz_width: CGFloat {
        set {
            var frame: CGRect = self.frame
            frame.size.width = newValue
            self.frame = frame
        }
        get {
            return self.frame.size.width
        }
    }
    
    var tz_height: CGFloat {
        set {
            var frame: CGRect = self.frame
            frame.size.height = newValue
            self.frame = frame
        }
        get {
            return self.frame.size.height
        }
    }
    
    var tz_centerX: CGFloat {
        set {
            self.center = CGPoint.init(x: newValue, y: self.center.y)
        }
        get {
            return self.center.x
        }
    }
    
    var tz_centerY: CGFloat {
        set {
            self.center = CGPoint.init(x: self.center.x, y: newValue)
        }
        get {
            return self.center.y
        }
    }
    
    var tz_origin: CGPoint {
        set {
            var frame: CGRect = self.frame
            frame.origin = newValue
            self.frame = frame
        }
        get {
            return self.frame.origin
        }
    }
    
    var tz_size: CGSize {
        set {
            var frame: CGRect = self.frame
            frame.size = newValue
            self.frame = frame
        }
        get {
            return self.frame.size
        }
    }
    
    static func showOscillatoryAnimationWith(layer: CALayer?, type:TZOscillatoryAnimationType) {
        
        let animationScale1 :Float = type == TZOscillatoryAnimationType.TZOscillatoryAnimationToBigger ? 1.15 : 0.5
        
        let animationScale2 :Float = type == TZOscillatoryAnimationType.TZOscillatoryAnimationToBigger ? 0.92 : 1.15
        
        UIView.animateKeyframes(withDuration: 0.15, delay: 0, options: UIView.KeyframeAnimationOptions(rawValue: UIView.AnimationOptions.beginFromCurrentState.rawValue | UIView.AnimationOptions.curveEaseInOut.rawValue), animations: {
            layer?.setValue(animationScale1, forKeyPath:"transform.scale")
        }) { (_) in
            UIView.animateKeyframes(withDuration: 0.15, delay: 0, options: UIView.KeyframeAnimationOptions(rawValue: UIView.AnimationOptions.beginFromCurrentState.rawValue | UIView.AnimationOptions.curveEaseInOut.rawValue), animations: {
                layer?.setValue(animationScale2, forKeyPath:"transform.scale")
            }) { (_) in
                UIView.animateKeyframes(withDuration: 0.1, delay: 0, options: UIView.KeyframeAnimationOptions(rawValue: UIView.AnimationOptions.beginFromCurrentState.rawValue | UIView.AnimationOptions.curveEaseInOut.rawValue), animations: {
                    layer?.setValue(1.0, forKeyPath:"transform.scale")
                })
            }
        }
    }
}
