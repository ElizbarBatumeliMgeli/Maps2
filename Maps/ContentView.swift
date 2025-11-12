//
//  ContentView.swift
//  Maps
//
//  Created by Antimo Bucciero on 11/11/25.
//
import SwiftUI

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    
    var body: some View {
        MapView(locationManager: locationManager)
    }
}

#Preview {
    ContentView()
}
