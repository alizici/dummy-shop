import 'package:dummy_shop/core/json/json_reader.dart';
import 'package:flutter_test/flutter_test.dart';

Matcher formatError(String path, {String? expected, String? found}) => isA<ResponseFormatException>()
    .having((e) => e.path, 'path', path)
    .having((e) => e.expected, 'expected', expected ?? anything)
    .having((e) => e.found, 'found', found ?? anything);

void main() {
  group('JsonReader', () {
    final json = JsonReader.root({
      'title': 'Mascara',
      'id': 1,
      'price': 9.99,
      'rating': 5,
      'inStock': true,
      'date': '2025-04-30T09:41:02.053Z',
      'brand': null,
      'tags': ['beauty', 'mascara'],
      'meta': {'barcode': '123'},
      'reviews': [
        {'name': 'Ada'},
        {'name': 42},
      ],
    });

    test('reads typed values', () {
      expect(json.string('title'), 'Mascara');
      expect(json.integer('id'), 1);
      expect(json.number('price'), 9.99);
      expect(json.boolean('inStock'), isTrue);
      expect(json.dateTime('date'), DateTime.utc(2025, 4, 30, 9, 41, 2, 53));
      expect(json.stringList('tags'), ['beauty', 'mascara']);
      expect(json.object('meta').string('barcode'), '123');
    });

    test('accepts a whole number where a decimal is expected', () {
      expect(json.number('rating'), 5.0);
    });

    test('a missing required field fails with its path instead of a default', () {
      expect(() => json.string('description'), throwsA(formatError(r'$.description', found: 'nothing')));
      expect(() => json.string('brand'), throwsA(formatError(r'$.brand', found: 'null')));
    });

    test('a wrong type fails with what was expected and what was found', () {
      expect(() => json.integer('price'), throwsA(formatError(r'$.price', expected: 'an integer', found: 'a number')));
      expect(() => json.string('id'), throwsA(formatError(r'$.id', expected: 'a string', found: 'an integer')));
    });

    test('optional reads return null only for missing or null', () {
      expect(json.stringOrNull('brand'), isNull);
      expect(json.stringOrNull('nothing'), isNull);
      expect(() => json.stringOrNull('id'), throwsA(formatError(r'$.id', expected: 'a string')));
    });

    test('paths go through nested objects and list items', () {
      List<String> names() => json.objects('reviews', (r) => r.string('name'));
      expect(names, throwsA(formatError(r'$.reviews[1].name', found: 'an integer')));
      expect(() => json.object('meta').integer('barcode'), throwsA(formatError(r'$.meta.barcode')));
    });

    test('OrEmpty lists treat absence as empty but still check the items', () {
      expect(json.stringListOrEmpty('missing'), isEmpty);
      expect(json.objectsOrEmpty('missing', (r) => r), isEmpty);
      expect(
        () => JsonReader.root({
          'tags': ['ok', 1],
        }).stringListOrEmpty('tags'),
        throwsA(formatError(r'$.tags[1]')),
      );
    });

    test('rejects a root that is not an object', () {
      expect(() => JsonReader.root([1, 2]), throwsA(formatError(r'$', expected: 'an object', found: 'a list')));
      expect(() => JsonReader.root(null), throwsA(formatError(r'$', found: 'null')));
    });

    test('rejects a date that is not ISO 8601', () {
      expect(
        () => JsonReader.root({'date': 'yesterday'}).dateTime('date'),
        throwsA(formatError(r'$.date', expected: 'an ISO 8601 date')),
      );
    });
  });
}
