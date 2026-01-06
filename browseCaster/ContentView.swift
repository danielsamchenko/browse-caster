import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Text("browseCaster")
                Text("Tap the Cast icon to find your Chromecast.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .navigationTitle("browseCaster")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    CastButtonView()
                        .frame(width: 28, height: 28)
                }
            }
        }
    }
}
