/// String helpers used when reading route parameters.
extension StringExtension on String {
  /// Parses this string as a boolean, or returns `null` when it is not one.
  ///
  /// Accepts `true`/`false` in any case, and any integer — zero is `false`,
  /// everything else `true`. Anything else is `null`.
  ///
  /// ```dart
  /// 'true'.toBoolOrNull();      // true
  /// 'TRUE'.toBoolOrNull();      // true
  /// 'false'.toBoolOrNull();     // false
  /// '1'.toBoolOrNull();         // true
  /// '0'.toBoolOrNull();         // false
  /// '-3'.toBoolOrNull();        // true
  /// 'something'.toBoolOrNull(); // null
  /// ''.toBoolOrNull();          // null
  /// ```
  ///
  /// In 1.x this returned `true` for unrecognised input — `?admin=no` read as
  /// `true` — because `int.tryParse('no') != 0` is `null != 0`.
  bool? toBoolOrNull() {
    switch (toLowerCase()) {
      case 'true':
        return true;
      case 'false':
        return false;
    }
    final asInt = int.tryParse(this);
    if (asInt != null) return asInt != 0;
    return null;
  }
}
