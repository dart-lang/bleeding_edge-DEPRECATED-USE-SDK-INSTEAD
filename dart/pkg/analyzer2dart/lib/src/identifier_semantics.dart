// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/**
 * Code for classifying the semantics of identifiers appearing in a Dart file.
 */
library analyzer2dart.identifierSemantics;

import 'package:analyzer/analyzer.dart';
import 'package:analyzer/src/generated/element.dart';

/**
 * Enum representing the different kinds of destinations which a property
 * access or method or function invocation might refer to.
 */
class AccessKind {
  /**
   * The destination of the access is an instance method, property, or field
   * of a class, and thus must be determined dynamically.
   */
  static const AccessKind DYNAMIC = const AccessKind._('DYNAMIC');

  /**
   * The destination of the access is a function that is defined locally within
   * an enclosing function or method.
   */
  static const AccessKind LOCAL_FUNCTION = const AccessKind._('LOCAL_FUNCTION');

  /**
   * The destination of the access is a variable that is defined locally within
   * an enclosing function or method.
   */
  static const AccessKind LOCAL_VARIABLE = const AccessKind._('LOCAL_VARIABLE');

  /**
   * The destination of the access is a variable that is defined as a parameter
   * to an enclosing function or method.
   */
  static const AccessKind PARAMETER = const AccessKind._('PARAMETER');

  /**
   * The destination of the access is a field that is defined statically within
   * a class, or a top level variable within a library.
   */
  static const AccessKind STATIC_FIELD = const AccessKind._('STATIC_FIELD');

  /**
   * The destination of the access is a method that is defined statically
   * within a class, or at top level within a library.
   */
  static const AccessKind STATIC_METHOD = const AccessKind._('STATIC_METHOD');

  /**
   * The destination of the access is a property getter/setter that is defined
   * statically within a class, or at top level within a library.
   */
  static const AccessKind STATIC_PROPERTY =
      const AccessKind._('STATIC_PROPERTY');

  final String name;

  String toString() => name;

  const AccessKind._(this.name);
}

/**
 * Data structure used to classify the semantics of a property access or method
 * or function invocation.
 */
class AccessSemantics {
  /**
   * The kind of access.
   */
  final AccessKind kind;

  /**
   * The identifier being used to access the property, method, or function.
   */
  final SimpleIdentifier identifier;

  /**
   * The element being accessed, if statically known.  This will be null if
   * [kind] is DYNAMIC or if the element is undefined (e.g. an attempt to
   * access a non-existent static method in a class).
   */
  final Element element;

  /**
   * The class containing the element being accessed, if this is a static
   * reference to an element in a class.  This will be null if [kind] is
   * DYNAMIC, LOCAL_FUNCTION, LOCAL_VARIABLE, or PARAMETER, or if the element
   * being accessed is defined at toplevel within a library.
   *
   * Note: it is possible for [classElement] to be non-null and for [element]
   * to be null; for example this occurs if the element being accessed is a
   * non-existent static method or field inside an existing class.
   */
  final ClassElement classElement;

  // TODO(paulberry): would it also be useful to store the libraryElement?

  /**
   * When [kind] is DYNAMIC, the expression whose runtime type determines the
   * class in which [identifier] should be looked up.  Null if the expression
   * is implicit "this".
   *
   * When [kind] is not DYNAMIC, this field is always null.
   */
  final Expression target;

  /**
   * True if this is an invocation of a method, or a call on a property.
   */
  final bool isInvoke;

  AccessSemantics.dynamic(this.identifier, this.target, {this.isInvoke: false})
      : kind = AccessKind.DYNAMIC,
        element = null,
        classElement = null;

  AccessSemantics.localFunction(this.identifier, this.element, {this.isInvoke:
      false})
      : kind = AccessKind.LOCAL_FUNCTION,
        classElement = null,
        target = null;

  AccessSemantics.localVariable(this.identifier, this.element, {this.isInvoke:
      false})
      : kind = AccessKind.LOCAL_VARIABLE,
        classElement = null,
        target = null;

  AccessSemantics.parameter(this.identifier, this.element, {this.isInvoke:
      false})
      : kind = AccessKind.PARAMETER,
        classElement = null,
        target = null;

  AccessSemantics.staticField(this.identifier, this.element, this.classElement,
      {this.isInvoke: false})
      : kind = AccessKind.STATIC_FIELD,
        target = null;

  AccessSemantics.staticMethod(this.identifier, this.element, this.classElement,
      {this.isInvoke: false})
      : kind = AccessKind.STATIC_METHOD,
        target = null;

  AccessSemantics.staticProperty(this.identifier, this.element,
      this.classElement, {this.isInvoke: false})
      : kind = AccessKind.STATIC_PROPERTY,
        target = null;

  /**
   * True if this is a read access to a property, or a method tear-off.  Note
   * that both [isRead] and [isWrite] will be true in the case of a
   * read-modify-write operation (e.g. "+=").
   */
  bool get isRead => !isInvoke && identifier.inGetterContext();

  /**
   * True if this is a write access to a property, or an (erroneous) attempt to
   * write to a method.  Note that both [isRead] and [isWrite] will be true in
   * the case of a read-modify-write operation (e.g. "+=").
   */
  bool get isWrite => identifier.inSetterContext();
}

/**
 * Return the semantics for [node].
 */
AccessSemantics classifyMethodInvocation(MethodInvocation node) {
  Expression target = node.realTarget;
  Element staticElement = node.methodName.staticElement;
  if (target == null) {
    if (staticElement is FunctionElement) {
      if (staticElement.enclosingElement is CompilationUnitElement) {
        return new AccessSemantics.staticMethod(
            node.methodName,
            staticElement,
            null,
            isInvoke: true);
      } else {
        return new AccessSemantics.localFunction(
            node.methodName,
            staticElement,
            isInvoke: true);
      }
    } else if (staticElement is MethodElement && staticElement.isStatic) {
      return new AccessSemantics.staticMethod(
          node.methodName,
          staticElement,
          staticElement.enclosingElement,
          isInvoke: true);
    } else if (staticElement is PropertyAccessorElement) {
      if (staticElement.isSynthetic) {
        if (staticElement.enclosingElement is CompilationUnitElement) {
          return new AccessSemantics.staticField(
              node.methodName,
              staticElement.variable,
              null,
              isInvoke: true);
        } else if (staticElement.isStatic) {
          return new AccessSemantics.staticField(
              node.methodName,
              staticElement.variable,
              staticElement.enclosingElement,
              isInvoke: true);
        }
      } else {
        if (staticElement.enclosingElement is CompilationUnitElement) {
          return new AccessSemantics.staticProperty(
              node.methodName,
              staticElement,
              null,
              isInvoke: true);
        } else if (staticElement.isStatic) {
          return new AccessSemantics.staticProperty(
              node.methodName,
              staticElement,
              staticElement.enclosingElement,
              isInvoke: true);
        }
      }
    } else if (staticElement is LocalVariableElement) {
      return new AccessSemantics.localVariable(
          node.methodName,
          staticElement,
          isInvoke: true);
    } else if (staticElement is ParameterElement) {
      return new AccessSemantics.parameter(
          node.methodName,
          staticElement,
          isInvoke: true);
    }
  } else if (target is Identifier) {
    Element targetStaticElement = target.staticElement;
    if (targetStaticElement is PrefixElement) {
      if (staticElement == null) {
        return new AccessSemantics.dynamic(
            node.methodName,
            null,
            isInvoke: true);
      } else if (staticElement is PropertyAccessorElement) {
        if (staticElement.isSynthetic) {
          return new AccessSemantics.staticField(
              node.methodName,
              staticElement.variable,
              null,
              isInvoke: true);
        } else {
          return new AccessSemantics.staticProperty(
              node.methodName,
              staticElement,
              null,
              isInvoke: true);
        }
      } else {
        return new AccessSemantics.staticMethod(
            node.methodName,
            staticElement,
            null,
            isInvoke: true);
      }
    } else if (targetStaticElement is ClassElement) {
      if (staticElement is PropertyAccessorElement) {
        if (staticElement.isSynthetic) {
          return new AccessSemantics.staticField(
              node.methodName,
              staticElement.variable,
              targetStaticElement,
              isInvoke: true);
        } else {
          return new AccessSemantics.staticProperty(
              node.methodName,
              staticElement,
              targetStaticElement,
              isInvoke: true);
        }
      } else {
        return new AccessSemantics.staticMethod(
            node.methodName,
            staticElement,
            targetStaticElement,
            isInvoke: true);
      }
    }
  }
  return new AccessSemantics.dynamic(node.methodName, target, isInvoke: true);
}

/**
 * Return the access semantics for [node].
 */
AccessSemantics classifyPrefixedIdentifier(PrefixedIdentifier node) {
  return _classifyPrefixed(node.prefix, node.identifier);
}

/**
 * Helper function for classifying an expression of type
 * Identifier.SimpleIdentifier.
 */
AccessSemantics _classifyPrefixed(Identifier lhs, SimpleIdentifier rhs) {
  Element lhsElement = lhs.staticElement;
  Element rhsElement = rhs.staticElement;
  if (lhsElement is PrefixElement) {
    if (rhsElement is PropertyAccessorElement) {
      if (rhsElement.isSynthetic) {
        return new AccessSemantics.staticField(rhs, rhsElement.variable, null);
      } else {
        return new AccessSemantics.staticProperty(rhs, rhsElement, null);
      }
    } else if (rhsElement is FunctionElement) {
      return new AccessSemantics.staticMethod(rhs, rhsElement, null);
    } else {
      return new AccessSemantics.dynamic(rhs, null);
    }
  } else if (lhsElement is ClassElement) {
    if (rhsElement is PropertyAccessorElement && rhsElement.isSynthetic) {
      return new AccessSemantics.staticField(
          rhs,
          rhsElement.variable,
          lhsElement);
    } else if (rhsElement is MethodElement) {
      return new AccessSemantics.staticMethod(rhs, rhsElement, lhsElement);
    } else {
      return new AccessSemantics.staticProperty(rhs, rhsElement, lhsElement);
    }
  } else {
    return new AccessSemantics.dynamic(rhs, lhs);
  }
}

/**
 * Return the access semantics for [node].
 */
AccessSemantics classifyPropertyAccess(PropertyAccess node) {
  if (node.target is Identifier) {
    return _classifyPrefixed(node.target, node.propertyName);
  } else {
    return new AccessSemantics.dynamic(node.propertyName, node.realTarget);
  }
}

/**
 * Return the access semantics for [node].
 *
 * Note: if [node] is the right hand side of a [PropertyAccess] or
 * [PrefixedIdentifier], or the method name of a [MethodInvocation], the return
 * value is null, since the semantics are determined by the parent.  In
 * practice these cases should never arise because the parent will visit the
 * parent node before visiting this one.
 */
AccessSemantics classifySimpleIdentifier(SimpleIdentifier node) {
  AstNode parent = node.parent;
  if (node.inDeclarationContext()) {
    // This identifier is a declaration, not a use.
    return null;
  }
  if (parent is TypeName) {
    // TODO(paulberry): handle this case.  Or, perhaps it would be better to
    // require clients not to visit the children of a TypeName when visiting
    // the AST structure.
    //
    // TODO(paulberry): be sure to consider type literals, e.g.:
    //   class A {}
    //   var a = A;
    return null;
  }
  if ((parent is PropertyAccess && parent.propertyName == node) ||
      (parent is PrefixedIdentifier && parent.identifier == node) ||
      (parent is MethodInvocation && parent.methodName == node)) {
    // The access semantics are determined by the parent.
    return null;
  }
  // TODO(paulberry): handle PrefixElement.
  Element staticElement = node.staticElement;
  if (staticElement is PropertyAccessorElement) {
    if (staticElement.isSynthetic) {
      if (staticElement.enclosingElement is CompilationUnitElement) {
        return new AccessSemantics.staticField(
            node,
            staticElement.variable,
            null);
      } else if (staticElement.isStatic) {
        return new AccessSemantics.staticField(
            node,
            staticElement.variable,
            staticElement.enclosingElement);
      }
    } else {
      if (staticElement.enclosingElement is CompilationUnitElement) {
        return new AccessSemantics.staticProperty(node, staticElement, null);
      } else if (staticElement.isStatic) {
        return new AccessSemantics.staticProperty(
            node,
            staticElement,
            staticElement.enclosingElement);
      }
    }
  } else if (staticElement is LocalVariableElement) {
    return new AccessSemantics.localVariable(node, staticElement);
  } else if (staticElement is ParameterElement) {
    return new AccessSemantics.parameter(node, staticElement);
  } else if (staticElement is FunctionElement) {
    if (staticElement.enclosingElement is CompilationUnitElement) {
      return new AccessSemantics.staticMethod(node, staticElement, null);
    } else {
      return new AccessSemantics.localFunction(node, staticElement);
    }
  } else if (staticElement is MethodElement && staticElement.isStatic) {
    return new AccessSemantics.staticMethod(
        node,
        staticElement,
        staticElement.enclosingElement);
  }
  return new AccessSemantics.dynamic(node, null);
}