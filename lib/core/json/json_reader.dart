/// Thrown when a response doesn't have the shape the app expects.
///
/// [path] points at the offending field (`$.products[3].price`), so a broken
/// response is found in seconds instead of turning into a wrong value on
/// screen.
class ResponseFormatException implements Exception {
  const ResponseFormatException(this.path, this.expected, this.found);

  final String path;
  final String expected;
  final String found;

  @override
  String toString() => 'ResponseFormatException: $path: expected $expected, found $found';
}

/// Strict, typed access to one decoded JSON object.
///
/// - A required read (`string`, `integer`, ...) throws [ResponseFormatException]
///   when the field is missing, null or of another type.
/// - An optional read (`stringOrNull`, ...) returns null only when the field
///   is missing or null; a present value of the wrong type still throws.
///
/// There are no silent defaults: a missing price never becomes `0`, a missing
/// title never becomes `''`. See docs/decisions/0002-strict-json-reader.md.
class JsonReader {
  JsonReader._(this._map, this.path);

  /// Reads [json], a value produced by `jsonDecode`, as the root object `$`.
  factory JsonReader.root(Object? json) => _asReader(json, r'$');

  final Map<String, Object?> _map;

  /// JSON path of this object, rooted at `$`.
  final String path;

  String string(String key) => _required(key, _string);
  String? stringOrNull(String key) => _optional(key, _string);

  int integer(String key) => _required(key, _integer);
  int? integerOrNull(String key) => _optional(key, _integer);

  /// A JSON number as a double; whole numbers (`5`) are accepted too.
  double number(String key) => _required(key, _number);
  double? numberOrNull(String key) => _optional(key, _number);

  bool boolean(String key) => _required(key, _boolean);

  /// An ISO 8601 date-time string.
  DateTime dateTime(String key) => _required(key, _dateTime);

  JsonReader object(String key) => _asReader(_present(key), _pathOf(key));
  JsonReader? objectOrNull(String key) {
    final value = _map[key];
    return value == null ? null : _asReader(value, _pathOf(key));
  }

  List<String> stringList(String key) =>
      _items(key).indexed.map((e) => _string(e.$2, '${_pathOf(key)}[${e.$1}]')).toList();

  /// Like [stringList], but a missing or null field is an empty list.
  /// Use only where "absent" really means "none" for the app.
  List<String> stringListOrEmpty(String key) => _map[key] == null ? const [] : stringList(key);

  /// A list of objects, each mapped with [read].
  List<T> objects<T>(String key, T Function(JsonReader item) read) =>
      _items(key).indexed.map((e) => read(_asReader(e.$2, '${_pathOf(key)}[${e.$1}]'))).toList();

  /// Like [objects], but a missing or null field is an empty list.
  List<T> objectsOrEmpty<T>(String key, T Function(JsonReader item) read) =>
      _map[key] == null ? const [] : objects(key, read);

  // ---------------------------------------------------------------------------

  T _required<T>(String key, T Function(Object? value, String path) cast) => cast(_present(key), _pathOf(key));

  T? _optional<T>(String key, T Function(Object? value, String path) cast) {
    final value = _map[key];
    return value == null ? null : cast(value, _pathOf(key));
  }

  Object _present(String key) {
    final value = _map[key];
    if (value == null) {
      throw ResponseFormatException(_pathOf(key), 'a value', _map.containsKey(key) ? 'null' : 'nothing');
    }
    return value;
  }

  List<Object?> _items(String key) {
    final value = _present(key);
    if (value is List<Object?>) return value;
    throw ResponseFormatException(_pathOf(key), 'a list', _describe(value));
  }

  String _pathOf(String key) => '$path.$key';

  static JsonReader _asReader(Object? value, String path) {
    if (value is Map<String, Object?>) return JsonReader._(value, path);
    throw ResponseFormatException(path, 'an object', _describe(value));
  }

  static String _string(Object? value, String path) =>
      value is String ? value : throw ResponseFormatException(path, 'a string', _describe(value));

  static int _integer(Object? value, String path) =>
      value is int ? value : throw ResponseFormatException(path, 'an integer', _describe(value));

  static double _number(Object? value, String path) =>
      value is num ? value.toDouble() : throw ResponseFormatException(path, 'a number', _describe(value));

  static bool _boolean(Object? value, String path) =>
      value is bool ? value : throw ResponseFormatException(path, 'a boolean', _describe(value));

  static DateTime _dateTime(Object? value, String path) {
    final text = _string(value, path);
    return DateTime.tryParse(text) ?? (throw ResponseFormatException(path, 'an ISO 8601 date', '"$text"'));
  }

  static String _describe(Object? value) => switch (value) {
    null => 'null',
    String() => 'a string',
    bool() => 'a boolean',
    int() => 'an integer',
    double() => 'a number',
    List<Object?>() => 'a list',
    Map<String, Object?>() => 'an object',
    _ => value.runtimeType.toString(),
  };
}
