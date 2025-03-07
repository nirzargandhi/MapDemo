//
//  MapVC.swift
//  MapDemo
//
//  Created by Nirzar Gandhi on 16/12/24.
//

import UIKit
import GoogleMaps
import GooglePlaces

class MapVC: UIViewController {
    
    // MARK: - IBOutlets
    @IBOutlet weak var mapView: GMSMapView!
    
    
    // MARK: - Properties
    private lazy var currentLocation = CLLocationCoordinate2D()
    private lazy var polyline = GMSPolyline()
    
    private lazy var pathCoordinates = [CLLocationCoordinate2D]()
    
    private var sourceMarker: GMSMarker?
    
    private lazy var sourceLatLong = CLLocationCoordinate2D(latitude: 19.1121, longitude: 72.8677)
    private lazy var destinationLatLong = CLLocationCoordinate2D(latitude: 19.1221, longitude: 72.8664)
    
    private lazy var cameraZoom: Float = 8.0
    private lazy var isMapAnimate = true
    
    
    // MARK: -
    // MARK: - View init Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "Home"
        
        self.setControlsProperty()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        
        if checkLocationStatus() {
            
            LocationManager.shared.locationManagerDelegate = self
            
            let camera = GMSCameraPosition.camera(withTarget: self.sourceLatLong, zoom: self.cameraZoom)
            self.mapView.animate(to: camera)
            self.setSourceDestinationMarker(source: nil)
            
        } else {
            LocationManager.shared.checkLocationPermision()
        }
    }
    
    fileprivate func setControlsProperty() {
        
        self.view.backgroundColor = .white
        self.view.isOpaque = false
        
        // MapView
        self.mapView.mapType = .normal
        self.mapView.setMinZoom(1, maxZoom: 20)
        
        self.mapView.isMyLocationEnabled = true
        
        self.mapView.settings.myLocationButton = true
        self.mapView.settings.zoomGestures = true
        self.mapView.settings.scrollGestures = true
        self.mapView.settings.rotateGestures = true
        self.mapView.settings.tiltGestures = true
    }
}


// MARK: -
// MARK: -  Call Back
extension MapVC {
    
    fileprivate func setSourceDestinationMarker(source: CLLocationCoordinate2D?) {
        
        //let source = CLLocationCoordinate2D(latitude: self.currentLocation.latitude, longitude: self.currentLocation.longitude) // Example: San Francisco
        
        // Add markers
        self.sourceMarker = GMSMarker(position: self.sourceLatLong)
        self.sourceMarker?.title = "Source"
        self.sourceMarker?.icon = UIImage(named: "ic_delivery")
        self.sourceMarker?.map = mapView
        
        let destinationMarker = GMSMarker(position: self.destinationLatLong)
        destinationMarker.title = "Destination"
        destinationMarker.map = mapView
        
        // Fetch and draw the route
        let sourceLocation = "\(self.sourceLatLong.latitude),\(self.sourceLatLong.longitude)"
        let destinationLocation = "\(self.destinationLatLong.latitude),\(self.destinationLatLong.longitude)"
        self.fetchRoute(from: sourceLocation, to: destinationLocation) { result in
            
            switch result {
                
            case .success(let json):
                guard let routes = json["routes"] as? [[String: Any]],
                      let firstRoute = routes.first,
                      let overviewPolyline = firstRoute["overview_polyline"] as? [String: Any],
                      let points = overviewPolyline["points"] as? String else { return }
                
                DispatchQueue.main.async {
                    
                    if let coordinates = self.decodePolyline(points) {
                        self.pathCoordinates = coordinates
                    }
                    
                    self.drawRoute(from: points)
                    
                    //                    if self.pathCoordinates.count > 0 {
                    //                        Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(self.updateTimerText), userInfo: nil, repeats: true)
                    //                    }
                    
                    if self.pathCoordinates.count > 0 {
                        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                            self.updateVehiclePosition()
                        }
                    }
                }
                
            case .failure(let error):
                print("Error fetching directions: \(error)")
            }
        }
    }
    
    fileprivate func fetchRoute(from source: String, to destination: String, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        
        let apiKey = "AIzaSyBbbmOJWHQIWp-MIPM6_8nt9q26Jg7--Pw"
        
        let urlString = "https://maps.googleapis.com/maps/api/directions/json?origin=\(source)&destination=\(destination)&mode=driving&key=\(apiKey)&optimize:true"
        
        guard let url = URL(string: urlString) else { return }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else { return }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    completion(.success(json))
                }
            } catch {
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
    
    fileprivate func decodePolyline(_ encodedString: String) -> [CLLocationCoordinate2D]? {
        
        var coordinates: [CLLocationCoordinate2D] = []
        var index = encodedString.startIndex
        let end = encodedString.endIndex
        var latitude = 0
        var longitude = 0
        
        while index < end {
            
            var result = 0
            var shift = 0
            var byte: Int
            
            repeat {
                byte = Int(encodedString[index].asciiValue! - 63)
                index = encodedString.index(after: index)
                result |= (byte & 0x1F) << shift
                shift += 5
            } while byte >= 0x20
            
            let deltaLat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1)
            latitude += deltaLat
            
            result = 0
            shift = 0
            
            repeat {
                byte = Int(encodedString[index].asciiValue! - 63)
                index = encodedString.index(after: index)
                result |= (byte & 0x1F) << shift
                shift += 5
            } while byte >= 0x20
            
            let deltaLon = (result & 1) != 0 ? ~(result >> 1) : (result >> 1)
            longitude += deltaLon
            
            let lat = Double(latitude) / 1E5
            let lon = Double(longitude) / 1E5
            coordinates.append(CLLocationCoordinate2D(latitude: lat, longitude: lon))
        }
        
        return coordinates
    }
    
    fileprivate func drawRoute(from encodedPath: String) {
        
        self.polyline.map = nil
        
        if self.pathCoordinates.count > 0 {
            
            let paths = GMSMutablePath()
            for coordinate in self.pathCoordinates {
                paths.addLatitude(coordinate.latitude, longitude: coordinate.longitude)
            }
            
            self.polyline.path = paths
            
        } else {
            
            guard let path = GMSPath(fromEncodedPath: encodedPath) else { return }
            
            self.polyline = GMSPolyline(path: path)
        }
        
        self.polyline.strokeColor = .red
        self.polyline.geodesic = true
        self.polyline.strokeWidth = 2.0
        self.polyline.map = self.mapView
        
        //if self.isMapAnimate {
        self.isMapAnimate = false
        self.mapView.animate(with: GMSCameraUpdate.fit(GMSCoordinateBounds(path: self.polyline.path!)))
        //}
    }
    
    fileprivate func calculateBearing(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) -> Double {
        
        let startLat = start.latitude.degreesToRadians
        let startLng = start.longitude.degreesToRadians
        let endLat = end.latitude.degreesToRadians
        let endLng = end.longitude.degreesToRadians
        
        let dLng = endLng - startLng
        let y = sin(dLng) * cos(endLat)
        let x = cos(startLat) * sin(endLat) - sin(startLat) * cos(endLat) * cos(dLng)
        let radiansBearing = atan2(y, x)
        
        return radiansBearing.radiansToDegrees//.truncatingRemainder(dividingBy: 360)
    }
    
    fileprivate func updateVehiclePosition() {
        
        if self.pathCoordinates.count > 1 {
            
            self.pathCoordinates.removeFirst()
            
            //self.setSourceDestinationMarker(source: self.pathCoordinates.first)
            self.drawRoute(from: "")
            
            if let position = self.sourceMarker?.position,
               let destination = self.pathCoordinates.first {
                
                self.moveVehicleMarkerWithRotation(to: destination, from: position)
                self.drawRoute(from: "")
            }
        }
    }
    
    fileprivate func moveVehicleMarkerWithRotation(to newPosition: CLLocationCoordinate2D, from oldPosition: CLLocationCoordinate2D) {
        
        let bearing = calculateBearing(from: oldPosition, to: newPosition)
        
        CATransaction.begin()
        CATransaction.setAnimationDuration(1.0)
        
        self.sourceMarker?.position = newPosition
        self.sourceMarker?.rotation = bearing
        
        CATransaction.commit()
    }
}


// MARK: -
// MARK: - LocationManager Delegate
extension MapVC: LocationManagerDelegate {
    
    func didUpdateLocation(_ location: CLLocation?) {
        
        if let currentLocation = location?.coordinate {
            
            self.currentLocation = currentLocation
            
            let camera = GMSCameraPosition.camera(withLatitude: currentLocation.latitude, longitude: currentLocation.longitude, zoom: self.cameraZoom)
            self.mapView.animate(to: camera)
        }
    }
}

// MARK: - Double
extension Double {
    var degreesToRadians: Double { return self * .pi / 180.0 }
    var radiansToDegrees: Double { return self * 180.0 / .pi }
}
