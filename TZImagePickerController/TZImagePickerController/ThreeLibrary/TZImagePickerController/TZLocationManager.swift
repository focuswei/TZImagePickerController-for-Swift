//
//  TZLocationManager.swift
//  TZImagePickerController
//
//  Created by FocusWei on 2019/11/25.
//  Copyright © 2019 FocusWei. All rights reserved.
//

import Foundation
import CoreLocation

class TZLocationManager {
    
    private var locationManager: CLLocationManager
    private var successClosure: ((_ array:Array<CLLocation>) -> Void)?
    private var failureClosure: ((_ error: Error) -> Void)?
    private var geocodeClosure: ((_ array: Array<AnyObject>) -> Void)?
    
    init() {
        self.locationManager = CLLocationManager.init()
        self.locationManager.requestWhenInUseAuthorization()
    }
    
    func startLocation() {
        self.startLocation(withClosure: nil, with: nil, with: nil)
    }
    
    func startLocation(withClosure success: ((_ array:Array<CLLocation>) -> Void)?, with failure: ((_ error: Error) -> Void)?) {
        self.startLocation(withClosure: success, with: failure, with: nil)
    }
    
    func startLocation(with geocoder: ((_ array: Array<AnyObject>) -> Void)?) {
        self.startLocation(withClosure: nil, with: nil, with: geocoder)
    }
    
    func startLocation(withClosure success: ((_ array:Array<CLLocation>) -> Void)?, with failure: ((_ error: Error) -> Void)?, with geocoder: ((_ array: Array<AnyObject>) -> Void)?) {
        self.locationManager.stopUpdatingLocation()
        self.successClosure = success
        self.geocodeClosure = geocoder
        self.failureClosure = failure
    }
    
    private func locationManager(manager: CLLocationManager, didUpdate locations:Array<CLLocation>) {
        manager.stopUpdatingLocation()
        
        self.successClosure?(locations)
        if locations.count > 0, let firstLocation = locations.first {
            let geocoder = CLGeocoder()
            geocoder.reverseGeocodeLocation(firstLocation) { [weak self] (array, error) in
                self?.geocodeClosure?(array ?? [])
            }
        }
    }
    

}
