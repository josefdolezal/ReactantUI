import UIKit
import SnapKit
import Reactant

private func findView(named name: String, in array: [(String, UIView)]) -> UIView? {
    return array.first(where: { $0.0 == name })?.1
}

public class ReactantLiveUIApplier {
    let definition: ComponentDefinition
    let instance: UIView
    let commonStyles: [Style]
    let setConstraint: (String, SnapKit.Constraint) -> Bool

    private var tempCounter: Int = 1

    public init(definition: ComponentDefinition,
                commonStyles: [Style],
                instance: UIView,
                setConstraint: @escaping (String, SnapKit.Constraint) -> Bool) {
        self.definition = definition
        self.commonStyles = commonStyles
        self.instance = instance
        self.setConstraint = setConstraint
    }

    public func apply() throws {
        instance.subviews.forEach { $0.removeFromSuperview() }
        let views = try definition.children.flatMap {
            try apply(element: $0, superview: instance, containedIn: definition)
        }
        tempCounter = 1
        try definition.children.forEach { try applyConstraints(views: views, element: $0, superview: instance) }
    }

    private func apply(element: UIElement, superview: UIView, containedIn: UIContainer) throws -> [(String, UIView)] {
        let name: String
        let view: UIView
        if let field = element.field {
            name = "\(field)"
            if instance is AnonymousLiveComponent {
                view = try element.initialize()
                instance.setValue(view, forUndefinedKey: field)
            } else if instance.responds(to: Selector("\(field)")) {
                guard let targetView = instance.value(forKey: field) as? UIView else {
                    throw LiveUIError(message: "Undefined field \(field)")
                }
                view = targetView
            } else if let mirrorView = Mirror(reflecting: instance).children.first(where: { $0.label == name })?.value as? UIView {
                view = mirrorView
            } else {
                throw LiveUIError(message: "Undefined field \(field)")
            }
        } else if let layoutId = element.layout.id {
            name = "named_\(layoutId)"
            view = try element.initialize()
        } else {
            name = "temp_\(type(of: element))_\(tempCounter)"
            tempCounter += 1
            view = try element.initialize()
        }

        for property in try (commonStyles + definition.styles).resolveStyle(for: element) {
            try property.apply(property, view)
        }

        containedIn.add(subview: view, toInstanceOfSelf: superview)

        if let container = element as? UIContainer {
            let children = try container.children.flatMap {
                try apply(element: $0, superview: view, containedIn: container)
            }

            return [(name, view)] + children
        } else {
            return [(name, view)]
        }
    }

    private func applyConstraints(views: [(String, UIView)], element: UIElement, superview: UIView) throws {
        let elementType = type(of: element)
        let name: String
        if let field = element.field {
            name = "\(field)"
        } else if let layoutId = element.layout.id {
            name = "named_\(layoutId)"
        } else {
            name = "temp_\(elementType)_\(tempCounter)"
            tempCounter += 1
        }

        guard let view = findView(named: name, in: views) else {
            throw LiveUIError(message: "Couldn't find view with name \(name) in view hierarchy")
        }

        if let horizontalCompressionPriority = element.layout.contentCompressionPriorityHorizontal {
            view.setContentCompressionResistancePriority(horizontalCompressionPriority.numeric, for: .horizontal)
        } else {
            view.setContentCompressionResistancePriority(elementType.defaultContentCompression.horizontal.numeric, for: .horizontal)
        }

        if let verticalCompressionPriority = element.layout.contentCompressionPriorityVertical {
            view.setContentCompressionResistancePriority(verticalCompressionPriority.numeric, for: .vertical)
        } else {
            view.setContentCompressionResistancePriority(elementType.defaultContentCompression.vertical.numeric, for: .vertical)
        }

        if let horizontalHuggingPriority = element.layout.contentHuggingPriorityHorizontal {
            view.setContentHuggingPriority(horizontalHuggingPriority.numeric, for: .horizontal)
        } else {
            view.setContentHuggingPriority(elementType.defaultContentHugging.horizontal.numeric, for: .horizontal)
        }

        if let verticalHuggingPriority = element.layout.contentHuggingPriorityVertical {
            view.setContentHuggingPriority(verticalHuggingPriority.numeric, for: .vertical)
        } else {
            view.setContentHuggingPriority(elementType.defaultContentHugging.vertical.numeric, for: .vertical)
        }

        var error: LiveUIError?

        view.snp.remakeConstraints { make in
            for constraint in element.layout.constraints {
                let maker: ConstraintMakerExtendable
                switch constraint.anchor {
                case .top:
                    maker = make.top
                case .bottom:
                    maker = make.bottom
                case .leading:
                    maker = make.leading
                case .trailing:
                    maker = make.trailing
                case .left:
                    maker = make.left
                case .right:
                    maker = make.right
                case .width:
                    maker = make.width
                case .height:
                    maker = make.height
                case .centerX:
                    maker = make.centerX
                case .centerY:
                    maker = make.centerY
                case .firstBaseline:
                    maker = make.firstBaseline
                case .lastBaseline:
                    maker = make.lastBaseline
                case .size:
                    maker = make.size
                }

                let target: ConstraintRelatableTarget

                switch constraint.type {
                case .targeted(let targetDefinition):
                    let targetView: UIView
                    switch targetDefinition.target {
                    case .field(let targetName):
                        guard let fieldView = findView(named: targetName, in: views) else {
                            error = LiveUIError(message: "Couldn't find view with field name `\(targetName)` in view hierarchy")
                            return
                        }
                        targetView = fieldView
                    case .layoutId(let layoutId):
                        let targetName = "named_\(layoutId)"
                        guard let fieldView = findView(named: targetName, in: views) else {
                            error = LiveUIError(message: "Couldn't find view with layout id `\(targetName)` in view hierarchy")
                            return
                        }
                        targetView = fieldView
                    case .parent:
                        targetView = superview
                    case .this:
                        targetView = view
                    }

                    if targetDefinition.targetAnchor != constraint.anchor {
                        switch targetDefinition.targetAnchor {
                        case .top:
                            target = targetView.snp.top
                        case .bottom:
                            target = targetView.snp.bottom
                        case .leading:
                            target = targetView.snp.leading
                        case .trailing:
                            target = targetView.snp.trailing
                        case .left:
                            target = targetView.snp.left
                        case .right:
                            target = targetView.snp.right
                        case .width:
                            target = targetView.snp.width
                        case .height:
                            target = targetView.snp.height
                        case .centerX:
                            target = targetView.snp.centerX
                        case .centerY:
                            target = targetView.snp.centerY
                        case .firstBaseline:
                            target = targetView.snp.firstBaseline
                        case .lastBaseline:
                            target = targetView.snp.lastBaseline
                        case .size:
                            target = targetView.snp.size
                        }
                    } else {
                        target = targetView
                    }

                case .constant(let constant):
                    target = constant
                }

                var editable: ConstraintMakerEditable
                switch constraint.relation {
                case .equal:
                    editable = maker.equalTo(target)
                case .greaterThanOrEqual:
                    editable = maker.greaterThanOrEqualTo(target)
                case .lessThanOrEqual:
                    editable = maker.lessThanOrEqualTo(target)
                }

                if case .targeted(let targetDefinition) = constraint.type {
                    if targetDefinition.constant != 0 {
                        editable = editable.offset(targetDefinition.constant)
                    }
                    if targetDefinition.multiplier != 1 {
                        editable = editable.multipliedBy(targetDefinition.multiplier)
                    }
                }

                let finalizable: ConstraintMakerFinalizable
                if constraint.priority.numeric != 1000 {
                    finalizable = editable.priority(constraint.priority.numeric)
                } else {
                    finalizable = editable
                }

                if let field = constraint.field {
                    guard setConstraint(field, finalizable.constraint) else {
                        error = LiveUIError(message: "Constraint cannot be set to field `\(field)`!")
                        return
                    }
                }
            }
        }

        if let error = error {
            throw error
        }

        if let container = element as? UIContainer {
            try container.children.forEach { try applyConstraints(views: views, element: $0, superview: view) }
        }
    }
}
