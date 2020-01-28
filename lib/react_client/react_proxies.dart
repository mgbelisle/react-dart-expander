library react_client.react_proxies;

import 'dart:js';
import 'dart:js_util';

import "package:js/js.dart";

import "package:react/react.dart";
import 'package:react/react_client.dart';
import 'package:react/react_client/react_interop.dart';
import 'package:react/react_client/utils.dart';
import 'package:react/src/context.dart';
import 'package:react/react_client/js_backed_map.dart';
import 'package:react/src/ddc_emulated_function_name_bug.dart' as ddc_emulated_function_name_bug;
import 'package:react/src/react_client/utils.dart';

/// Shared component factory proxy [build] method for components that utilize [JsBackedMap]s.
mixin JsBackedMapComponentFactoryMixin on ReactComponentFactoryProxy {
  @override
  ReactElement build(Map props, [List childrenArgs = const []]) {
    var children = generateChildren(childrenArgs, shouldAlwaysBeList: true);
    var convertedProps = generateExtendedJsProps(props);
    return React.createElement(type, convertedProps, children);
  }

  static JsMap generateExtendedJsProps(Map props) =>
      generateJsProps(props, convertEventHandlers: false, wrapWithJsify: false);
}

/// Use [ReactDartComponentFactoryProxy2] instead.
///
/// Will be removed when [Component] is removed in the `6.0.0` release.
@Deprecated('6.0.0')
class ReactDartComponentFactoryProxy<TComponent extends Component> extends ReactComponentFactoryProxy {
  /// The ReactJS class used as the type for all [ReactElement]s built by
  /// this factory.
  final ReactClass reactClass;

  /// The JS component factory used by this factory to build [ReactElement]s.
  final ReactJsComponentFactory reactComponentFactory;

  /// The cached Dart default props retrieved from [reactClass] that are passed
  /// into [generateExtendedJsProps] upon [ReactElement] creation.
  final Map defaultProps;

  ReactDartComponentFactoryProxy(ReactClass reactClass)
      : this.reactClass = reactClass,
        this.reactComponentFactory = React.createFactory(reactClass),
        this.defaultProps = reactClass.dartDefaultProps;

  ReactClass get type => reactClass;

  ReactElement build(Map props, [List childrenArgs = const []]) {
    var children = convertArgsToChildren(childrenArgs);
    children = listifyChildren(children);

    return reactComponentFactory(generateExtendedJsProps(props, children, defaultProps: defaultProps), children);
  }

  /// Returns a JavaScript version of the specified [props], preprocessed for consumption by ReactJS and prepared for
  /// consumption by the [react] library internals.
  static InteropProps generateExtendedJsProps(Map props, dynamic children, {Map defaultProps}) {
    if (children == null) {
      children = [];
    } else if (children is! Iterable) {
      children = [children];
    }

    // 1. Merge in defaults (if they were specified)
    // 2. Add specified props and children.
    // 3. Remove "reserved" props that should not be visible to the rendered component.

    // [1]
    Map extendedProps = (defaultProps != null ? new Map.from(defaultProps) : {})
    // [2]
      ..addAll(props)
      ..['children'] = children
    // [3]
      ..remove('key')
      ..remove('ref');

    var internal = new ReactDartComponentInternal()..props = extendedProps;

    var interopProps = new InteropProps(internal: internal);

    // Don't pass a key into InteropProps if one isn't defined, so that the value will
    // be `undefined` in the JS, which is ignored by React, whereas `null` isn't.
    if (props.containsKey('key')) {
      interopProps.key = props['key'];
    }

    if (props.containsKey('ref')) {
      var ref = props['ref'];

      // If the ref is a callback, pass ReactJS a function that will call it
      // with the Dart Component instance, not the ReactComponent instance.
      //
      // Use CallbackRef<Null> to check arity, since parameters could be non-dynamic, and thus
      // would fail the `is CallbackRef<dynamic>` check.
      // See https://github.com/dart-lang/sdk/issues/34593 for more information on arity checks.
      if (ref is CallbackRef<Null>) {
        interopProps.ref = allowInterop((ReactComponent instance) {
          // Call as dynamic to perform dynamic dispatch, since we can't cast to CallbackRef<dynamic>,
          // and since calling with non-null values will fail at runtime due to the CallbackRef<Null> typing.
          return (ref as dynamic)(instance?.dartComponent);
        });
      } else if (ref is Ref) {
        interopProps.ref = ref.jsRef;
      } else {
        interopProps.ref = ref;
      }
    }

    return interopProps;
  }
}

/// Creates ReactJS [Component2] instances for Dart components.
class ReactDartComponentFactoryProxy2<TComponent extends Component2> extends ReactComponentFactoryProxy
    with JsBackedMapComponentFactoryMixin
    implements ReactDartComponentFactoryProxy {
  /// The ReactJS class used as the type for all [ReactElement]s built by
  /// this factory.
  final ReactClass reactClass;

  /// The JS component factory used by this factory to build [ReactElement]s.
  final ReactJsComponentFactory reactComponentFactory;

  final Map defaultProps;

  ReactDartComponentFactoryProxy2(ReactClass reactClass)
      : this.reactClass = reactClass,
        this.reactComponentFactory = React.createFactory(reactClass),
        this.defaultProps = new JsBackedMap.fromJs(reactClass.defaultProps);

  ReactClass get type => reactClass;

  /// Returns a JavaScript version of the specified [props], preprocessed for consumption by ReactJS and prepared for
  /// consumption by the [react] library internals.
  static JsMap generateExtendedJsProps(Map props) =>
      generateJsProps(props, convertEventHandlers: false, wrapWithJsify: false);
}

/// Creates ReactJS [ReactElement] instances for `JSContext` components.
///
/// Adds special jsifying and unjsifying of the `value` prop.
class ReactJsContextComponentFactoryProxy extends ReactJsComponentFactoryProxy {
  /// The JS class used by this factory.
  @override
  final ReactClass type;
  final bool isConsumer;
  final bool isProvider;
  final Function factory;
  final bool shouldConvertDomProps;

  ReactJsContextComponentFactoryProxy(
      ReactClass jsClass, {
        this.shouldConvertDomProps: true,
        this.isConsumer: false,
        this.isProvider: false,
      })  : this.type = jsClass,
        this.factory = React.createFactory(jsClass),
        super(jsClass, shouldConvertDomProps: shouldConvertDomProps);

  @override
  ReactElement build(Map props, [List childrenArgs]) {
    dynamic children = generateChildren(childrenArgs);

    if (isConsumer) {
      if (children is Function) {
        Function contextCallback = children;
        children = allowInterop((args) {
          return contextCallback(ContextHelpers.unjsifyNewContext(args));
        });
      }
    }

    return React.createElement(type, generateExtendedJsProps(props), children);
  }

  /// Returns a JavaScript version of the specified [props], preprocessed for consumption by ReactJS and prepared for
  /// consumption by the [react] library internals.
  JsMap generateExtendedJsProps(Map props) {
    JsBackedMap propsForJs = new JsBackedMap.from(props);

    if (isProvider) {
      propsForJs['value'] = ContextHelpers.jsifyNewContext(propsForJs['value']);
    }

    return propsForJs.jsObject;
  }
}

/// Creates ReactJS [ReactElement] instances for components defined in the JS.
class ReactJsComponentFactoryProxy extends ReactComponentFactoryProxy {
  /// The JS class used by this factory.
  @override
  final ReactClass type;

  /// The JS component factory used by this factory to build [ReactElement]s.
  final Function factory;

  /// Whether to automatically prepare props relating to bound values and event handlers
  /// via [ReactDomComponentFactoryProxy.convertProps] for consumption by React JS DOM components.
  ///
  /// Useful when the JS component forwards DOM props to its rendered DOM components.
  ///
  /// Disable for more custom handling of these props.
  final bool shouldConvertDomProps;

  /// Whether the props.children should always be treated as a list or not.
  /// Default: `false`
  final bool alwaysReturnChildrenAsList;

  ReactJsComponentFactoryProxy(ReactClass jsClass,
      {this.shouldConvertDomProps: true, this.alwaysReturnChildrenAsList: false})
      : this.type = jsClass,
        this.factory = React.createFactory(jsClass) {
    if (jsClass == null) {
      throw new ArgumentError('`jsClass` must not be null. '
          'Ensure that the JS component class you\'re referencing is available and being accessed correctly.');
    }
  }

  @override
  ReactElement build(Map props, [List childrenArgs]) {
    dynamic children = generateChildren(childrenArgs, shouldAlwaysBeList: alwaysReturnChildrenAsList);
    JsMap convertedProps =
    generateJsProps(props, convertEventHandlers: shouldConvertDomProps, convertCallbackRefValue: false);
    return React.createElement(type, convertedProps, children);
  }
}

/// Creates ReactJS [ReactElement] instances for DOM components.
class ReactDomComponentFactoryProxy extends ReactComponentFactoryProxy {
  /// The name of the proxied DOM component.
  ///
  /// E.g. `'div'`, `'a'`, `'h1'`
  final String name;

  /// The JS component factory used by this factory to build [ReactElement]s.
  final Function factory;

  ReactDomComponentFactoryProxy(name)
      : this.name = name,
        this.factory = React.createFactory(name) {
    // TODO: Should we remove this once we validate that the bug is gone in Dart 2 DDC?
    if (ddc_emulated_function_name_bug.isBugPresent) {
      ddc_emulated_function_name_bug.patchName(this);
    }
  }

  @override
  String get type => name;

  @override
  ReactElement build(Map props, [List childrenArgs = const []]) {
    var children = generateChildren(childrenArgs);
    var convertedProps = generateJsProps(props, convertCallbackRefValue: false, wrapWithJsify: true);
    return React.createElement(type, convertedProps, children);
  }

  /// Performs special handling of certain props for consumption by ReactJS DOM components.
  static void convertProps(Map props) {
    convertEventHandlers(props);
    convertRefValue(props);
  }
}

/// Creates ReactJS [Function Component] from Dart Function.
class ReactDartFunctionComponentFactoryProxy extends ReactComponentFactoryProxy with JsBackedMapComponentFactoryMixin {
  /// The name of this function.
  final String displayName;

  /// The React JS component definition of this Function Component.
  final JsFunctionComponent reactFunction;

  ReactDartFunctionComponentFactoryProxy(DartFunctionComponent dartFunctionComponent, {String displayName})
      : this.displayName = displayName ?? _getJsFunctionName(dartFunctionComponent),
        this.reactFunction = _wrapFunctionComponent(dartFunctionComponent,
            displayName: displayName ?? _getJsFunctionName(dartFunctionComponent));

  @override
  JsFunctionComponent get type => reactFunction;

  static String _getJsFunctionName(Function object) =>
      getProperty(object, 'name') ?? getProperty(object, '\$static_name');

  /// Creates a function component from the given [dartFunctionComponent] that can be used with React.
  ///
  /// [displayName] Sets the component name for debugging purposes.
  ///
  /// In DDC, this will be the [DartFunctionComponent] name, but in dart2js it will be null unless
  /// overridden, since using runtimeType can lead to larger dart2js output.
  ///
  /// This will result in the dart2js name being `ReactDartComponent2` (the
  /// name of the proxying JS component defined in _dart_helpers.js).
  static JsFunctionComponent _wrapFunctionComponent(DartFunctionComponent dartFunctionComponent, {String displayName}) {
    // dart2js uses null and undefined interchangeably, meaning returning `null` from dart
    // may show up in js as `undefined`, ReactJS doesnt like that and expects a js `null` to be returned,
    // and throws if it gets `undefined`. `jsNull` is an interop variable that holds a JS `null` value
    // to force `null` as the return value if user returns a Dart `null`.
    // See: https://github.com/dart-lang/sdk/issues/27485
    jsFunctionComponent(JsMap jsProps, [JsMap _legacyContext]) =>
        dartFunctionComponent(JsBackedMap.backedBy(jsProps)) ?? jsNull;
    JsFunctionComponent interopFunction = allowInterop(jsFunctionComponent);
    if (displayName != null) {
      // This is a work-around to display the correct name in the React DevTools.
      defineProperty(interopFunction, 'name', jsify({'value': displayName}));
    }
    // ignore: invalid_use_of_protected_member
    setProperty(interopFunction, 'dartComponentVersion', ReactDartComponentVersion.component2);
    return interopFunction;
  }
}
