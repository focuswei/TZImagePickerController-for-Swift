//
//  TZProgressView.swift
//  TZImagePickerController
//
//  Created by guozw3 on 2019/11/12.
//  Copyright © 2019 centaline. All rights reserved.
//

import UIKit

class TZProgressView: UIView {

    var progress: Double = 0.0 {
        didSet {
            self.setNeedsDisplay()
        }
    }
    fileprivate var progressLayer: CAShapeLayer
    
    init() {
        progressLayer = CAShapeLayer()
        progressLayer.fillColor = UIColor.clear.cgColor
        progressLayer.strokeColor = UIColor.white.cgColor
        progressLayer.opacity = 1
        progressLayer.lineCap = CAShapeLayerLineCap.round
        progressLayer.lineWidth = 5
        
        progressLayer.shadowColor = UIColor.black.cgColor
        progressLayer.shadowOffset = CGSize.init(width: 1, height: 1)
        progressLayer.shadowOpacity = 0.5
        progressLayer.shadowRadius = 2
        super.init(frame: CGRect.zero)
        self.backgroundColor = UIColor.clear
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ rect: CGRect) {
        let center: CGPoint = CGPoint.init(x: rect.size.width / 2, y: rect.size.height / 2)
        let radius: CGFloat = rect.size.width / 2
        let startA: CGFloat = CGFloat(-Double.pi/2)
        let endA: CGFloat = CGFloat(-Double.pi/2 + Double.pi * 2 * progress)
        
        progressLayer.frame = self.bounds
        let path = UIBezierPath.init(arcCenter: center, radius: radius, startAngle: startA, endAngle: endA, clockwise: true)
        progressLayer.path = path.cgPath
        
        progressLayer.removeFromSuperlayer()
        self.layer.addSublayer(progressLayer)
    }
}
