@TestOn('browser')
import 'package:test/test.dart';

import 'package:react/react.dart' as react;
import 'package:react/react_client.dart';
import 'package:react/react_test_utils.dart' as rtu;

import 'common_factory_tests.dart';

main() {
  setClientConfiguration();

  group('ReactDartComponentFactoryProxy', () {
    test('has a type corresponding to the backing JS class', () {
      expect(Foo.type, equals(Foo.reactClass));
    });

    group('- common factory behavior -', () {
      commonFactoryTests(Foo);
    });

    group('- refs -', () {
      refTests(Foo, verifyRefValue: (ref) {
        expect(ref, const isInstanceOf<_Foo>());
      });
    });
  });
}

final Foo = react.registerComponent(() => new _Foo()) as ReactDartComponentFactoryProxy;

class _Foo extends react.Component {
  @override
  render() => react.div({});
}
