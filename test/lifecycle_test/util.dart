import 'package:matcher/matcher.dart';
import 'package:react/react.dart';

const Map defaultProps = const {'defaultProp': 'default'};
const Map emptyChildrenProps = const {'children': const []};

Map matchCall(String memberName, {args: anything, props: anything, state: anything, context: anything}) {
  return {
    'memberName': memberName,
    'arguments': args,
    'props': props,
    'state': state,
    'context': context,
  };
}

/// A test helper to record lifecycle calls
mixin LifecycleTestHelper on Component {
  dynamic context;
  Map props;
  Map state;

  static List staticLifecycleCalls = [];

  /// We needed to add [staticLifecycleCalls] to be able to test static
  /// lifecycle methods like [getDerivedStateFromProps] and
  /// [getDerivedStateFromError], which don't get called on the same instance
  /// as other lifecycle methods.
  ///
  /// This alllows static and instance lifecycle methods to add calls to the same list
  List get lifecycleCalls => staticLifecycleCalls;

  List get lifecycleCallMemberNames => staticLifecycleCalls.map((call) {
        return call['memberName'];
      }).toList();

  dynamic lifecycleCall(String memberName, {List arguments: const [], defaultReturnValue(), Map staticProps}) {
    print('lifecycle $memberName');
    print('State ${state.toString()}');
    lifecycleCalls.add({
      'memberName': memberName,
      'arguments': arguments,
      'props': props == null ? null : new Map.from(props),
      'state': state == null ? null : new Map.from(state),
      'context': context,
    });

    var lifecycleCallback = props == null ? staticProps == null ? null : staticProps[memberName] : props[memberName];
    if (lifecycleCallback != null) {
      return Function.apply(
          lifecycleCallback,
          []
            ..add(this)
            ..addAll(arguments));
    }

    print('lifecycle $memberName');
    print('State ${state.toString()}');

    if (defaultReturnValue != null) {
      return defaultReturnValue();
    }

    return null;
  }

  void callSetStateWithNullValue() {
    setState(null);
  }
}

abstract class DefaultPropsCachingTestHelper implements Component {
  int get staticGetDefaultPropsCallCount;
  set staticGetDefaultPropsCallCount(int value);
}
