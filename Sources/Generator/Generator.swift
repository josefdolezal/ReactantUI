import Foundation
import Tokenizer

public class Generator {

    let localXmlPath: String
    let isLiveEnabled: Bool

    var nestLevel: Int = 0

    init(localXmlPath: String, isLiveEnabled: Bool) {
        self.localXmlPath = localXmlPath
        self.isLiveEnabled = isLiveEnabled
    }

    func generate(imports: Bool) {

    }

    func l(_ line: String = "") {
        print((0..<nestLevel).map { _ in "    " }.joined() + line)
    }

    func l(_ line: String = "", _ f: () -> Void) {
        print((0..<nestLevel).map { _ in "    " }.joined() + line, terminator: "")

        nestLevel += 1
        print(" {")
        f()
        nestLevel -= 1
        l("}")
    }
}

public class UIGenerator: Generator {
    public let root: ComponentDefinition

    private var tempCounter: Int = 1

    public init(definition: ComponentDefinition, localXmlPath: String, isLiveEnabled: Bool) {
        self.root = definition
        super.init(localXmlPath: localXmlPath, isLiveEnabled: isLiveEnabled)
    }

    public override func generate(imports: Bool) {
        if root.isAnonymous {
            l("final class \(root.type): ViewBase<Void, Void>") { }
        }
        let constraintFields = root.children.flatMap(self.constraintFields)
        l("extension \(root.type): ReactantUI" + (root.isRootView ? ", RootView" : "")) {
            if root.isRootView {
                l("var edgesForExtendedLayout: UIRectEdge") {
                    if isLiveEnabled {
                        l("#if (arch(i386) || arch(x86_64)) && os(iOS)")
                        l("return ReactantLiveUIManager.shared.extendedEdges(of: self)")
                        l("#else")
                    }
                    l("return \(SupportedPropertyValue.rectEdge(root.edgesForExtendedLayout).generated)")
                    if isLiveEnabled {
                        l("#endif")
                    }
                }
            }
            l()
            l("var rui: \(root.type).RUIContainer") {
                l("return Reactant.associatedObject(self, key: &\(root.type).RUIContainer.associatedObjectKey)") {
                    l("return \(root.type).RUIContainer(target: self)")
                }
            }
            l()
            l("var __rui: Reactant.ReactantUIContainer") {
                l("return rui")
            }
            l()
            l("final class RUIContainer: Reactant.ReactantUIContainer") {
                l("fileprivate static var associatedObjectKey = 0 as UInt8")
                l()
                l("var xmlPath: String") {
                    l("return \"\(localXmlPath)\"")
                }
                l()
                l("var typeName: String") {
                    l("return \"\(root.type)\"")
                }
                l()
                l("let constraints = \(root.type).LayoutContainer()")
                l()
                l("private weak var target: \(root.type)?")
                l()
                l("fileprivate init(target: \(root.type))") {
                    l("self.target = target")
                }
                l()
                l("func setupReactantUI()") {
                    l("guard let target = self.target else { /* FIXME Should we fatalError here? */ return }")
                    if isLiveEnabled {
                        l("#if (arch(i386) || arch(x86_64)) && os(iOS)")
                        // This will register `self` to remove `deinit` from ViewBase
                        l("ReactantLiveUIManager.shared.register(target)") {

                            if constraintFields.isEmpty {
                                l("_ in")
                                l("return false")
                            } else {
                                l("[constraints] field, constraint -> Bool in")
                                l("switch field") {
                                    for constraintField in constraintFields {
                                        l("case \"\(constraintField)\":")
                                        l("    constraints.\(constraintField) = constraint")
                                        l("    return true")
                                    }
                                    l("default:")
                                    l("    return false")
                                }
                            }
                        }
                        l("#else")
                    }
                    root.children.forEach { generate(element: $0, superName: "target", containedIn: root) }
                    tempCounter = 1
                    root.children.forEach { generateConstraints(element: $0, superName: "target") }
                    if isLiveEnabled {
                        l("#endif")
                    }
                }
                l()
                l("static func destroyReactantUI(target: UIView)") {
                    if isLiveEnabled {
                        l("#if (arch(i386) || arch(x86_64)) && os(iOS)")
                        l("guard let knownTarget = target as? \(root.type) else { /* FIXME Should we fatalError here? */ return }")
                        l("ReactantLiveUIManager.shared.unregister(knownTarget)")
                        l("#endif")
                    }
                }
            }
            l()
            l("final class LayoutContainer") {
                for constraintField in constraintFields {
                    l("fileprivate(set) var \(constraintField): SnapKit.Constraint?")
                }
            }
            generateStyles()
        }
    }

    private func generate(element: UIElement, superName: String, containedIn: UIContainer) {
        let name: String
        if let field = element.field {
            name = "target.\(field)"
        } else if let layoutId = element.layout.id {
            name = "named_\(layoutId)"
            l("let \(name) = \(element.initialization)")
        } else {
            name = "temp_\(type(of: element))_\(tempCounter)"
            tempCounter += 1
            l("let \(name) = \(element.initialization)")
        }

        for style in element.styles {
            if style.hasPrefix(":") {
                let components = style.substring(from: style.index(style.startIndex, offsetBy: 1)).components(separatedBy: ":")
                if components.count != 2 {
                    print("// Global style \(style) assignment has wrong format.")
                }
                let stylesName = components[0].capitalizingFirstLetter() + "Styles"
                let style = components[1]

                l("\(name).apply(style: \(stylesName).\(style))")
            } else {
                l("\(name).apply(style: \(root.stylesName).\(style))")
            }
        }

        for property in element.properties {
            l(property.application(property, name))
        }
        l("\(superName).\(containedIn.addSubviewMethod)(\(name))")
        l()
        if let container = element as? UIContainer {
            container.children.forEach { generate(element: $0, superName: name, containedIn: container) }
        }
    }

    private func generateConstraints(element: UIElement, superName: String) {
        let name: String
        if let field = element.field {
            name = "target.\(field)"
        } else if let layoutId = element.layout.id {
            name = "named_\(layoutId)"
        } else {
            name = "temp_\(type(of: element))_\(tempCounter)"
            tempCounter += 1
        }

        if let horizontalCompressionPriority = element.layout.contentCompressionPriorityHorizontal {
            l("\(name).setContentCompressionResistancePriority(\(horizontalCompressionPriority.numeric), for: .horizontal)")
        }

        if let verticalCompressionPriority = element.layout.contentCompressionPriorityVertical {
            l("\(name).setContentCompressionResistancePriority(\(verticalCompressionPriority.numeric), for: .vertical)")
        }

        if let horizontalHuggingPriority = element.layout.contentHuggingPriorityHorizontal {
            l("\(name).setContentHuggingPriority(\(horizontalHuggingPriority.numeric), for: .horizontal)")
        }

        if let verticalHuggingPriority = element.layout.contentHuggingPriorityVertical {
            l("\(name).setContentHuggingPriority(\(verticalHuggingPriority.numeric), for: .vertical)")
        }

        l("\(name).snp.makeConstraints") {
            l("make in")
            for constraint in element.layout.constraints {
                //let x = UIView().widthAnchor

                var constraintLine = "make.\(constraint.anchor).\(constraint.relation)("

                switch constraint.type {
                case .targeted(let targetDefinition):
                    let target: String
                    switch targetDefinition.target {
                    case .field(let targetName):
                        target = "target.\(targetName)"
                    case .layoutId(let layoutId):
                        target = "named_\(layoutId)"
                    case .parent:
                        target = superName
                    case .this:
                        target = name
                    }
                    constraintLine += target
                    if targetDefinition.targetAnchor != constraint.anchor {
                        constraintLine += ".snp.\(targetDefinition.targetAnchor)"
                    }

                case .constant(let constant):
                    constraintLine += "\(constant)"
                }
                constraintLine += ")"

                if case .targeted(let targetDefinition) = constraint.type {
                    if targetDefinition.constant != 0 {
                        constraintLine += ".offset(\(targetDefinition.constant))"
                    }
                    if targetDefinition.multiplier != 1 {
                        constraintLine += ".multipliedBy(\(targetDefinition.multiplier))"
                    }
                }

                if constraint.priority.numeric != 1000 {
                    constraintLine += ".priority(\(constraint.priority.numeric))"
                }

                if let field = constraint.field {
                    constraintLine = "constraints.\(field) = \(constraintLine).constraint"
                }

                l(constraintLine)
            }
        }

        if let container = element as? UIContainer {
            container.children.forEach { generateConstraints(element: $0, superName: name) }
        }
    }

    private func constraintFields(element: UIElement) -> [String] {
        var fields = [] as [String]
        for constraint in element.layout.constraints {
            guard let field = constraint.field else { continue }

            fields.append(field)
        }

        if let container = element as? UIContainer {
            return fields + container.children.flatMap(constraintFields)
        } else {
            return fields
        }
    }

    private func generateStyles() {
        l("struct \(root.stylesName)") {
            for style in root.styles {
                l("static func \(style.name)(_ view: \(Element.elementMapping[style.type]?.runtimeType ?? "UIView"))") {
                    for extendedStyle in style.extend {
                        l("\(root.stylesName).\(extendedStyle)(view)")
                    }
                    for property in style.properties {
                        l(property.application(property, "view"))
                    }
                }
            }
        }
    }
}
