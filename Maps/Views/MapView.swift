import SwiftUI
import MapKit

struct MapView: View {
    @ObservedObject var locationManager: LocationManager
    @State private var cameraPosition: MapCameraPosition = .automatic
    
    //Bottom sheet properites
    @State private var showBottomSheet: Bool = true
    @State private var sheetDetent: PresentationDetent = .height(80)
    @State private var sheetHeight: CGFloat = 0
    @State private var animationDuration: CGFloat = 0
    @State private var toolbarOpacity: CGFloat = 1
    @State private var safeAreaBottomInsert: CGFloat = 0
    var body: some View {
        // Mappa centrata sulla posizione dell'utente
        Map(position: $cameraPosition){
            UserAnnotation()
        }
        .sheet(isPresented: $showBottomSheet){
            BottomSheetView(sheetDetent: $sheetDetent)
                .presentationDetents(
                    [.height(80), .height(350), .large],
                    selection: $sheetDetent
                )
                .presentationBackgroundInteraction(.enabled)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onGeometryChange(for: CGFloat.self) {
                    max(min($0.size.height, 400 + safeAreaBottomInsert), 0)
                } action: { oldValue, newValue in
                    sheetHeight = min(newValue, 350 + safeAreaBottomInsert)
                    
                    ///Calculating Opacity
                    
                    let progress = max(min((newValue - (350 + safeAreaBottomInsert)) / 50,1),0)
                    toolbarOpacity = 1 - progress
                    
                    ///Calculating Animation Duration
                    
                    let diff = abs(newValue - oldValue)
                    let duration = max(min(diff / 100, 0.3),0)
                    animationDuration = duration
                }
                .ignoresSafeArea()
                .interactiveDismissDisabled()
        }
        .overlay(alignment: .bottomTrailing){
            BottomFloatinToolBar()
                .padding(.trailing, 30)
                .offset(y: safeAreaBottomInsert - 10)
        }
        .onGeometryChange(for: CGFloat.self) {
            $0.safeAreaInsets.bottom
        } action: { newValue in
            safeAreaBottomInsert = newValue
        }
    }
    ///Bottom Floating View
    @ViewBuilder
    func BottomFloatinToolBar() -> some View {
        VStack(spacing: 35){
            Button{
                
            } label: {
                Image(systemName: "car.fill")
            }
            
            Button{
                
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
}

struct BottomSheetView: View {
    @Binding var sheetDetent: PresentationDetent
    /// Bottom Sheet Properites
    @State private var searchText: String = ""
    @FocusState var isFocused: Bool
    var body: some View {
        ScrollView(.vertical){
            
        }
        .safeAreaInset(edge: .top, spacing: 0){
            HStack(spacing:10){
                TextField("Search...", text: $searchText)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.gray.opacity(0.25), in: .capsule)
                    .focused($isFocused)
                ///Profile and Close button for search field
                Button {
                    if isFocused {
                        isFocused = false
                    }else{
                        //profile button action
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
    }
}

#Preview{
    MapView(locationManager: LocationManager())
}
