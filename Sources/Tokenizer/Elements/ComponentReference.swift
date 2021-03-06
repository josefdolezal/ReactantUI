import Foundation

#if ReactantRuntime
import UIKit
#endif

public class ComponentReference: View, ComponentDefinitionContainer {
    public let type: String
    public let definition: ComponentDefinition?

    public var isAnonymous: Bool {
        return definition?.isAnonymous ?? false
    }

    public var componentTypes: [String] {
        return definition?.componentTypes ?? [type]
    }

    public var componentDefinitions: [ComponentDefinition] {
        return definition?.componentDefinitions ?? []
    }

    public class override var runtimeType: String {
        return "UIView"
    }

    public override var initialization: String {
        return "\(type)()"
    }

    public required init(node: SWXMLHash.XMLElement) throws {
        type = try node.value(ofAttribute: "type")
        if !node.xmlChildren.isEmpty {
            definition = try node.value() as ComponentDefinition
        } else {
            definition = nil
        }
        
        try super.init(node: node)
    }

    #if ReactantRuntime
    public override func initialize() throws -> UIView {
        return try ReactantLiveUIManager.shared.componentInstantiation(named: type)()
    }
    #endif
}
