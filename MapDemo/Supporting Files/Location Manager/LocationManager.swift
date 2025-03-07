//
//  LocationManager.swift
//  MapDemo
//
//  Created by Nirzar Gandhi on 16/12/24.
//

import Foundation
import CoreLocation
import UIKit

protocol LocationManagerDelegate {
    
    func didUpdateLocation(_ location: CLLocation?)
}

class LocationManager: NSObject {
    
    // MARK: - Properties
    static let shared: LocationManager = {
        let instance = LocationManager()
        return instance
    }()
    
    lazy var clLocation = CLLocationManager()
    var currentLocation: CLLocation?
    
    var locationManagerDelegate: LocationManagerDelegate?
    
    
    // MARK: - Init
    private override init() { }
}


// MARK: -
// MARK: - Call
extension LocationManager {
    
    func checkLocationPermision() {
        
        DispatchQueue.global().async {
            
            if CLLocationManager.locationServicesEnabled() {
                
                switch CLLocationManager.authorizationStatus() {
                    
                case .notDetermined:
                    self.getUserLocation()
                    
                case .authorizedWhenInUse:
                    self.showLocationPermissionAlert(isNotAuthorizedAlways: true)
                    
                case.authorizedAlways:
                    self.clLocation.delegate = self
                    self.clLocation.startUpdatingLocation()
                    self.clLocation.startMonitoringSignificantLocationChanges()
                    
                case .denied, .restricted:
                    self.showLocationPermissionAlert()
                    
                @unknown default:
                    break
                }
                
            } else {
                self.getUserLocation()
            }
        }
    }
    
    fileprivate func getUserLocation() {
        
        self.clLocation.delegate = self
        self.clLocation.desiredAccuracy = kCLLocationAccuracyBest
        self.clLocation.distanceFilter = kCLDistanceFilterNone
        self.clLocation.activityType = .other
        
        self.clLocation.allowsBackgroundLocationUpdates = true
        self.clLocation.showsBackgroundLocationIndicator = true
        self.clLocation.pausesLocationUpdatesAutomatically = false
        
        self.clLocation.requestAlwaysAuthorization()
        //self.clLocation.requestWhenInUseAuthorization() - // If adding in resident app, no need to use always authorization. We can use this.
    }
    
    fileprivate func showLocationPermissionAlert(isNotAuthorizedAlways : Bool = false) {
        
        DispatchQueue.main.async {
            let alertController = UIAlertController(title: isNotAuthorizedAlways ? "Always Authorize Location" : "Location Permission Required", message: isNotAuthorizedAlways ? "We require \"Always\" permission for fetching location in background mode" : "Please enable location permissions in settings.", preferredStyle: UIAlertController.Style.alert)
            
            let okAction = UIAlertAction(title: "Open Settings", style: .default, handler: { _ in
                
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl, options: [:], completionHandler: nil)
                }
            })
            
            alertController.addAction(okAction)
            
            APPDELEOBJ.window?.rootViewController?.present(alertController, animated: true, completion: nil)
        }
    }
    
    fileprivate func stopLoaction() {
        self.clLocation.stopUpdatingLocation()
    }
}


// MARK: -
// MARK: - CLLocationManager Delegate
extension LocationManager: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        
        switch status {
            
        case .denied, .restricted:
            self.showLocationPermissionAlert()
            
        case .notDetermined:
            self.getUserLocation()
            
        case .authorizedWhenInUse:
            self.showLocationPermissionAlert(isNotAuthorizedAlways: true)
            
        case .authorizedAlways:
            self.clLocation.delegate = self
            self.clLocation.startUpdatingLocation()
            self.clLocation.startMonitoringSignificantLocationChanges()
            
        default:
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        self.currentLocation = locations.first
        
        self.stopLoaction()
        
        if let delegate = self.locationManagerDelegate {
            delegate.didUpdateLocation(self.currentLocation)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("LocationManager fail with error \(error.localizedDescription)")
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        print(newHeading.magneticHeading)
    }
}
