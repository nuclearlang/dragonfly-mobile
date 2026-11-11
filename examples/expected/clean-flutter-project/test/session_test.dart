import 'package:clean_flutter_project/components/session/data/auth_repository.dart';
import 'package:clean_flutter_project/components/session/domain/models/auth.dart';
import 'package:clean_flutter_project/components/session/session_component.dart';
import 'package:clean_flutter_project/dragonfly.g.dart';
import 'package:clean_flutter_project/shared/events/force_logout.dart';
import 'package:dragonfly/dragonfly.dart';
import 'package:dragonfly/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

/// Session tests: the repository is a mock; the session, the ACL and the events are the real ones.
Auth rick() {
  return Auth(userId: '1', name: 'Rick', token: 't', roles: ['admin']);
}

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  group('SessionTest', () {
    setUp(() async {
      await DragonflyTest.start(dragonflyConfig(), registerDragonfly);
      DragonflyTest.replace<AuthRepository>(MockAuthRepository());
    });

    setUp(() async {
      registerFallbackValue(LoginParams(user: '', pass: ''));
      when(() => inject<AuthRepository>().login(any())).thenReturnAsync(Right(rick()));
    });

    test('login starts a session; admin inherits the role fan', () async {
      expect(
        await inject<SessionComponent>().login('rick', 'c-137'),
        isOkWith(rick()),
      );
      expect(inject<SessionManager>().get<Auth>().name, 'Rick');
      expect(Acl.can(roles: ['fan']), isTrue);
    });

    test('the backend forces a logout through a global component', () async {
      await inject<SessionComponent>().login('rick', 'c-137');
      Events.publish(ForceLogout(reason: 'password changed'));
      await pumpEventQueue();
      expect(inject<SessionManager>().active, isFalse);
    });
  });
}
