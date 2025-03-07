//
//  Common.swift
//  MapDemo
//
//  Created by Nirzar Gandhi on 16/12/24.
//

import Foundation
import CoreLocation

// MARK: - Check Location Status
func checkLocationStatus() -> Bool {
    
    var isAuthorized = false
    
    if #available(iOS 14.0, *) {
        
        let stauts = LocationManager.shared.clLocation.authorizationStatus
        if stauts == .authorizedAlways {
            isAuthorized = true
        }
        
    } else {
        
        let stauts = CLLocationManager.authorizationStatus()
        if stauts == .authorizedAlways {
            isAuthorized = true
        }
    }
    
    return isAuthorized
}
