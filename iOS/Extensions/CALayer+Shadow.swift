import UIKit

extension CALayer {
    /// Apply a futuristic shadow effect to the layer
    func applyFuturisticShadow() {
        masksToBounds = false
        shadowColor = UIColor(red: 0.1, green: 0.6, blue: 1.0, alpha: 1.0).cgColor
        shadowOffset = CGSize(width: 0, height: 3)
        shadowOpacity = 0.3
        shadowRadius = 10
    }
}