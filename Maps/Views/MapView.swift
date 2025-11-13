// MapView.swift

import SwiftUI
import MapKit

struct MapView: View {
    @ObservedObject var locationManager: LocationManager
    @StateObject private var searchViewModel = SearchViewModel()
    @State private var cameraPosition: MapCameraPosition = .automatic
    
    @State private var showBottomSheet: Bool = true
    @State private var sheetDetent: PresentationDetent = .height(80)
    @State private var sheetHeight: CGFloat = 0
    @State private var animationDuration: CGFloat = 0
    @State private var toolbarOpacity: CGFloat = 1
    @State private var safeAreaBottomInsert: CGFloat = 0
    
    var body: some View {
        Map(position: $cameraPosition){
            UserAnnotation()
            
            if let mapItem = searchViewModel.selectedMapItem {
                Annotation(mapItem.name ?? "Location", coordinate: mapItem.placemark.coordinate) {
                    Image(systemName: iconForCategory(mapItem.pointOfInterestCategory))
                        .font(.headline)
                        .padding(8)
                        .background(Color.red)
                        .foregroundStyle(.white)
                        .clipShape(Circle())
                }
            }
            
            if let route = searchViewModel.route {
                MapPolyline(route.polyline)
                    .stroke(.blue, lineWidth: 5)
            }
        }
        .sheet(isPresented: $showBottomSheet){
            BottomSheetView(sheetDetent: $sheetDetent, searchViewModel: searchViewModel, locationManager: locationManager)
                .presentationDetents(
                    [.height(80), .height(350), .large],
                    selection: $sheetDetent
                )
                .presentationBackgroundInteraction(.enabled)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onGeometryChange(for: CGFloat.self, of: { proxy in
                    max(min(proxy.size.height, 400 + safeAreaBottomInsert), 0)
                }) { oldValue, newValue in
                    sheetHeight = min(newValue, 350 + safeAreaBottomInsert)
                    let progress = max(min((newValue - (350 + safeAreaBottomInsert)) / 50,1),0)
                    toolbarOpacity = 1 - progress
                    let diff = abs(newValue - oldValue)
                    let duration = max(min(diff / 100, 0.3),0)
                    animationDuration = duration
                }
                .ignoresSafeArea()
                .interactiveDismissDisabled()
        }
        .overlay(alignment: .bottomTrailing){
            BottomFloatinToolBar(locationManager: locationManager, searchViewModel: searchViewModel)
                .padding(.trailing, 30)
                .offset(y: safeAreaBottomInsert - 10)
        }
        .onGeometryChange(for: CGFloat.self, of: { proxy in
            proxy.safeAreaInsets.bottom
        }) { oldValue, newValue in
            safeAreaBottomInsert = newValue
        }
        .onChange(of: searchViewModel.selectedMapItem) {
            if let mapItem = searchViewModel.selectedMapItem {
                let region = MKCoordinateRegion(center: mapItem.placemark.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
                cameraPosition = .region(region)
            }
        }
        .onChange(of: searchViewModel.route) {
            if let route = searchViewModel.route {
                let rect = route.polyline.boundingMapRect.insetBy(dx: -1000, dy: -1000)
                cameraPosition = .rect(rect)
            }
        }
    }
    
    @ViewBuilder
    func BottomFloatinToolBar(locationManager: LocationManager, searchViewModel: SearchViewModel) -> some View {
        VStack(spacing: 35){
            Button{
                searchViewModel.getDirections(from: locationManager.region.center)
            } label: {
                Image(systemName: "car.fill")
            }
            .disabled(searchViewModel.selectedMapItem == nil)
            
            Button{
                cameraPosition = .region(locationManager.region)
            } label: {
                Image(systemName: "location")
            }
        }
        .font(.title3)
        .foregroundStyle(Color.primary)
        .padding(.vertical, 20)
        .padding(.horizontal, 13)
        .glassEffect(.regular, in: .capsule)
        .opacity(toolbarOpacity)
        .offset(y: -sheetHeight)
        .animation(.interpolatingSpring(duration: animationDuration, bounce: 0, initialVelocity: 0), value: sheetHeight)
    }
    
    private func iconForCategory(_ category: MKPointOfInterestCategory?) -> String {
        guard let category = category else { return "mappin" }
        
        switch category {
        case .restaurant, .cafe:
            return "fork.knife"
        case .store:
            return "cart"
        case .hotel:
            return "bed.double"
        case .atm, .bank:
            return "dollarsign.circle"
        case .gasStation:
            return "fuelpump"
        case .parking:
            return "parkingsign"
        case .movieTheater:
            return "popcorn"
        case .museum:
            return "building.columns"
        case .airport:
            return "airplane"
        case .hospital, .pharmacy:
            return "cross.case"
        default:
            return "mappin"
        }
    }
}

struct BottomSheetView: View {
    @Binding var sheetDetent: PresentationDetent
    @ObservedObject var searchViewModel: SearchViewModel
    @ObservedObject var locationManager: LocationManager // <--- ADDED
    
    @FocusState var isFocused: Bool
    
    var body: some View {
        ScrollView(.vertical){
            if isFocused {
                LazyVStack(spacing: 0) {
                    ForEach(searchViewModel.searchResults, id: \.self) { completion in
                        HStack(spacing: 12) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.gray)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(completion.title)
                                    .font(.headline)
                                    .fontWeight(.medium)
                                Text(completion.subtitle)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            isFocused = false
                            searchViewModel.selectSearchCompletion(completion, userLocation: locationManager.region.center)
                        }
                        Divider()
                    }
                }
            } else if let mapItem = searchViewModel.selectedMapItem {
                VStack(alignment: .leading, spacing: 15) {
                    Text(mapItem.name ?? "Selected Location")
                        .font(.title)
                        .fontWeight(.bold)

                    if let address = mapItem.placemark.title {
                        Text(address)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Divider()
                    
                    if let route = searchViewModel.route {
                        HStack(spacing: 8) {
                            Image(systemName: "car.fill")
                            Text("Est. Time:")
                            Text(formatTime(route.expectedTravelTime))
                                .fontWeight(.medium)
                        }
                        HStack(spacing: 8) {
                            Image(systemName: "road.lanes")
                            Text("Distance:")
                            Text(Measurement(value: route.distance, unit: UnitLength.meters)
                                .formatted(.measurement(width: .abbreviated, usage: .road)))
                                .fontWeight(.medium)
                        }
                    } else if let distance = searchViewModel.distanceToDestination {
                        HStack(spacing: 8) {
                            Image(systemName: "location.north.line.fill")
                            Text("Distance (as the crow flies):")
                            Text(Measurement(value: distance, unit: UnitLength.meters)
                                .formatted(.measurement(width: .abbreviated, usage: .road)))
                                .fontWeight(.medium)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0){
            HStack(spacing:10){
                TextField("Search...", text: $searchViewModel.searchText)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.gray.opacity(0.25), in: .capsule)
                    .focused($isFocused)
                
                Button {
                    if isFocused {
                        isFocused = false
                        if !searchViewModel.searchText.isEmpty {
                            searchViewModel.searchText = ""
                        }
                    }else{
                        
                    }
                } label:{
                    ZStack{
                        if isFocused{
                            Image(systemName: "xmark")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.primary)
                                .frame(width: 48, height: 48)
                                .glassEffect(in: .circle)
                                .transition(.blurReplace)
                        }else {
                            Text("AB")
                                .font(.title2.bold())
                                .frame(width:48, height: 48)
                                .foregroundStyle(.white)
                                .background(.gray, in: .circle)
                                .transition(.blurReplace)
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .frame(height:80)
            .padding(.top, 5)
        }
        .animation(.interpolatingSpring(duration: 0.3, bounce: 0, initialVelocity: 0),value: isFocused)
        .onChange(of: isFocused){ oldValue, newValue in
            sheetDetent = newValue ? .large : .height(350)
        }
        .onChange(of: searchViewModel.searchText) {
            if !isFocused && !searchViewModel.searchText.isEmpty {
                isFocused = true
            }
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = [.hour, .minute]
        return formatter.string(from: time) ?? ""
    }
}

#Preview{
    MapView(locationManager: LocationManager())
}
