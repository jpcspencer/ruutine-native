import SwiftUI

extension Font {
    static func bebas(_ size: CGFloat) -> Font {
        .custom("BebasNeue-Regular", size: size)
    }
}

extension View {
    func bebasFont(_ size: CGFloat) -> some View {
        font(.custom("BebasNeue-Regular", size: size))
    }
}
