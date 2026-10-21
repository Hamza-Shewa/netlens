import 'package:netlens/netlens_mocks.dart';
import 'package:test/test.dart';

import 'mock_test_data.dart';

void main() {
  group('NetLensDefaultMockMatcher', () {
    const NetLensDefaultMockMatcher matcher = NetLensDefaultMockMatcher();

    test('matches method, host and path', () {
      expect(
        matcher.matches(mock(), request('https://api.example.com/users')),
        isTrue,
      );
      expect(
        matcher.matches(
          mock(),
          request('https://api.example.com/users', method: 'post'),
        ),
        isFalse,
      );
      expect(
        matcher.matches(mock(), request('https://other.example.com/users')),
        isFalse,
      );
      expect(
        matcher.matches(mock(), request('https://api.example.com/teams')),
        isFalse,
      );
    });

    test('ignores the case of the method and trailing slashes', () {
      expect(
        matcher.matches(
          mock(),
          request('https://api.example.com/users/', method: 'get'),
        ),
        isTrue,
      );
    });

    test('matches any host when the request has none', () {
      expect(matcher.matches(mock(), request('/users')), isTrue);
    });

    test('matches any host when hosts are not compared', () {
      expect(
        const NetLensDefaultMockMatcher(
          matchHost: false,
        ).matches(mock(), request('http://localhost:8080/users')),
        isTrue,
      );
    });

    test('matches any segment with a wildcard', () {
      final NetLensMock wildcard = mock(
        url: 'https://api.example.com/users/*/posts',
      );
      expect(
        matcher.matches(
          wildcard,
          request('https://api.example.com/users/42/posts'),
        ),
        isTrue,
      );
      expect(
        matcher.matches(wildcard, request('https://api.example.com/users/42')),
        isFalse,
      );
    });

    test('compares query parameters in any order', () {
      final NetLensMock withQuery = mock(
        url: 'https://api.example.com/users?page=1&sort=name',
      );
      expect(
        matcher.matches(
          withQuery,
          request('https://api.example.com/users?sort=name&page=1'),
        ),
        isTrue,
      );
      expect(
        matcher.matches(
          withQuery,
          request('https://api.example.com/users?page=2&sort=name'),
        ),
        isFalse,
      );
      expect(
        const NetLensDefaultMockMatcher(
          matchQuery: false,
        ).matches(withQuery, request('https://api.example.com/users?page=2')),
        isTrue,
      );
    });

    test('skips ignored query parameters', () {
      expect(
        const NetLensDefaultMockMatcher(
          ignoredQueryParameters: {'_t'},
        ).matches(mock(), request('https://api.example.com/users?_t=123')),
        isTrue,
      );
    });

    test('compares bodies only when asked, and JSON by value', () {
      final NetLensMock withBody = mock(
        method: 'POST',
        requestBody: '{"name":"Ada","age":36}',
      );
      final NetLensMockRequest reordered = request(
        'https://api.example.com/users',
        method: 'POST',
        body: '{ "age": 36, "name": "Ada" }',
      );
      final NetLensMockRequest other = request(
        'https://api.example.com/users',
        method: 'POST',
        body: '{"name":"Bob"}',
      );
      expect(matcher.matches(withBody, other), isTrue);
      const NetLensDefaultMockMatcher bodyMatcher = NetLensDefaultMockMatcher(
        matchBody: true,
      );
      expect(bodyMatcher.matches(withBody, reordered), isTrue);
      expect(bodyMatcher.matches(withBody, other), isFalse);
    });

    test('never matches a disabled mock', () {
      expect(
        matcher.matches(
          mock(enabled: false),
          request('https://api.example.com/users'),
        ),
        isFalse,
      );
    });
  });
}
