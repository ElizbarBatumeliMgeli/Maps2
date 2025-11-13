//
//  SearchViewModel.swift
//  Maps
//
//  Created by Elizbar Kheladze on 13/11/25.
//

// SearchViewModel.swift

import Foundation
import MapKit
internal import Combine

@MainActor
class SearchViewModel: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    
    @Published var searchText: String = ""
    @Published var searchResults: [MKLocalSearchCompletion] = []
    @Published var selectedMapItem: MKMapItem?
    @Published var route: MKRoute?
    @Published var distanceToDestination: CLLocationDistance?
    
    private var completer: MKLocalSearchCompleter
    private var cancellable: AnyCancellable?
    private var isUpdatingFromSelection: Bool = false

    override init() {
        completer = MKLocalSearchCompleter()
        super.init()
        completer.delegate = self
        
        cancellable = $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] newText in
                guard let self = self else { return }
                
                if self.isUpdatingFromSelection {
                    return
                }
                
                if !newText.isEmpty {
                    self.completer.queryFragment = newText
                    self.route = nil
                    self.selectedMapItem = nil
                    self.distanceToDestination = nil
                } else {
                    self.searchResults = []
                }
            }
    }
    
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        self.searchResults = completer.results
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("Search completer failed: \(error.localizedDescription)")
    }
    
    func selectSearchCompletion(_ completion: MKLocalSearchCompletion, userLocation: CLLocationCoordinate2D) {
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        
        Task {
            do {
                let response = try await search.start()
                if let mapItem = response.mapItems.first {
                    
                    self.isUpdatingFromSelection = true
                    self.searchText = mapItem.name ?? ""
                    DispatchQueue.main.async {
                        self.isUpdatingFromSelection = false
                    }

                    self.selectedMapItem = mapItem
                    self.searchResults = []
                    self.route = nil
                    
                    let userCLLocation = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
                    if let destinationLocation = mapItem.placemark.location {
                        let distance = userCLLocation.distance(from: destinationLocation)
                        self.distanceToDestination = distance
                    }
                }
            } catch {
                print("Failed to get map item from completion: \(error.localizedDescription)")
            }
        }
    }
    
    func getDirections(from userLocation: CLLocationCoordinate2D) {
        guard let destination = selectedMapItem else {
            print("No destination selected.")
            return
        }
        
        self.distanceToDestination = nil
        
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: userLocation))
        request.destination = destination
        request.transportType = .automobile

        let directions = MKDirections(request: request)
        Task {
            do {
                let response = try await directions.calculate()
                if let route = response.routes.first {
                    self.route = route
                }
            } catch {
                print("Failed to calculate directions: \(error.localizedDescription)")
            }
        }
    }
}

