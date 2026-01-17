import AppKit
import ObjectiveC

private var documentStateKey: UInt8 = 0

extension NSWindow {
    var documentState: DocumentState? {
        get {
            objc_getAssociatedObject(self, &documentStateKey) as? DocumentState
        }
        set {
            objc_setAssociatedObject(self, &documentStateKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}
