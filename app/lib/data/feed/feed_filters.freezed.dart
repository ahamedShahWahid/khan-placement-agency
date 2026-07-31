// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'feed_filters.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$FeedFilters {
  String? get query;
  List<String> get locations;
  int? get minYears;
  double? get minCtc;

  /// Create a copy of FeedFilters
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $FeedFiltersCopyWith<FeedFilters> get copyWith =>
      _$FeedFiltersCopyWithImpl<FeedFilters>(this as FeedFilters, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is FeedFilters &&
            (identical(other.query, query) || other.query == query) &&
            const DeepCollectionEquality().equals(other.locations, locations) &&
            (identical(other.minYears, minYears) ||
                other.minYears == minYears) &&
            (identical(other.minCtc, minCtc) || other.minCtc == minCtc));
  }

  @override
  int get hashCode => Object.hash(runtimeType, query,
      const DeepCollectionEquality().hash(locations), minYears, minCtc);

  @override
  String toString() {
    return 'FeedFilters(query: $query, locations: $locations, minYears: $minYears, minCtc: $minCtc)';
  }
}

/// @nodoc
abstract mixin class $FeedFiltersCopyWith<$Res> {
  factory $FeedFiltersCopyWith(
          FeedFilters value, $Res Function(FeedFilters) _then) =
      _$FeedFiltersCopyWithImpl;
  @useResult
  $Res call(
      {String? query, List<String> locations, int? minYears, double? minCtc});
}

/// @nodoc
class _$FeedFiltersCopyWithImpl<$Res> implements $FeedFiltersCopyWith<$Res> {
  _$FeedFiltersCopyWithImpl(this._self, this._then);

  final FeedFilters _self;
  final $Res Function(FeedFilters) _then;

  /// Create a copy of FeedFilters
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? query = freezed,
    Object? locations = null,
    Object? minYears = freezed,
    Object? minCtc = freezed,
  }) {
    return _then(_self.copyWith(
      query: freezed == query
          ? _self.query
          : query // ignore: cast_nullable_to_non_nullable
              as String?,
      locations: null == locations
          ? _self.locations
          : locations // ignore: cast_nullable_to_non_nullable
              as List<String>,
      minYears: freezed == minYears
          ? _self.minYears
          : minYears // ignore: cast_nullable_to_non_nullable
              as int?,
      minCtc: freezed == minCtc
          ? _self.minCtc
          : minCtc // ignore: cast_nullable_to_non_nullable
              as double?,
    ));
  }
}

/// Adds pattern-matching-related methods to [FeedFilters].
extension FeedFiltersPatterns on FeedFilters {
  /// A variant of `map` that fallback to returning `orElse`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>(
    TResult Function(_FeedFilters value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _FeedFilters() when $default != null:
        return $default(_that);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// Callbacks receives the raw object, upcasted.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case final Subclass2 value:
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult map<TResult extends Object?>(
    TResult Function(_FeedFilters value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _FeedFilters():
        return $default(_that);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `map` that fallback to returning `null`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>(
    TResult? Function(_FeedFilters value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _FeedFilters() when $default != null:
        return $default(_that);
      case _:
        return null;
    }
  }

  /// A variant of `when` that fallback to an `orElse` callback.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>(
    TResult Function(String? query, List<String> locations, int? minYears,
            double? minCtc)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _FeedFilters() when $default != null:
        return $default(
            _that.query, _that.locations, _that.minYears, _that.minCtc);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// As opposed to `map`, this offers destructuring.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case Subclass2(:final field2):
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult when<TResult extends Object?>(
    TResult Function(String? query, List<String> locations, int? minYears,
            double? minCtc)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _FeedFilters():
        return $default(
            _that.query, _that.locations, _that.minYears, _that.minCtc);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `when` that fallback to returning `null`
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>(
    TResult? Function(String? query, List<String> locations, int? minYears,
            double? minCtc)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _FeedFilters() when $default != null:
        return $default(
            _that.query, _that.locations, _that.minYears, _that.minCtc);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _FeedFilters extends FeedFilters {
  const _FeedFilters(
      {this.query,
      final List<String> locations = const <String>[],
      this.minYears,
      this.minCtc})
      : _locations = locations,
        super._();

  @override
  final String? query;
  final List<String> _locations;
  @override
  @JsonKey()
  List<String> get locations {
    if (_locations is EqualUnmodifiableListView) return _locations;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_locations);
  }

  @override
  final int? minYears;
  @override
  final double? minCtc;

  /// Create a copy of FeedFilters
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$FeedFiltersCopyWith<_FeedFilters> get copyWith =>
      __$FeedFiltersCopyWithImpl<_FeedFilters>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _FeedFilters &&
            (identical(other.query, query) || other.query == query) &&
            const DeepCollectionEquality()
                .equals(other._locations, _locations) &&
            (identical(other.minYears, minYears) ||
                other.minYears == minYears) &&
            (identical(other.minCtc, minCtc) || other.minCtc == minCtc));
  }

  @override
  int get hashCode => Object.hash(runtimeType, query,
      const DeepCollectionEquality().hash(_locations), minYears, minCtc);

  @override
  String toString() {
    return 'FeedFilters(query: $query, locations: $locations, minYears: $minYears, minCtc: $minCtc)';
  }
}

/// @nodoc
abstract mixin class _$FeedFiltersCopyWith<$Res>
    implements $FeedFiltersCopyWith<$Res> {
  factory _$FeedFiltersCopyWith(
          _FeedFilters value, $Res Function(_FeedFilters) _then) =
      __$FeedFiltersCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String? query, List<String> locations, int? minYears, double? minCtc});
}

/// @nodoc
class __$FeedFiltersCopyWithImpl<$Res> implements _$FeedFiltersCopyWith<$Res> {
  __$FeedFiltersCopyWithImpl(this._self, this._then);

  final _FeedFilters _self;
  final $Res Function(_FeedFilters) _then;

  /// Create a copy of FeedFilters
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? query = freezed,
    Object? locations = null,
    Object? minYears = freezed,
    Object? minCtc = freezed,
  }) {
    return _then(_FeedFilters(
      query: freezed == query
          ? _self.query
          : query // ignore: cast_nullable_to_non_nullable
              as String?,
      locations: null == locations
          ? _self._locations
          : locations // ignore: cast_nullable_to_non_nullable
              as List<String>,
      minYears: freezed == minYears
          ? _self.minYears
          : minYears // ignore: cast_nullable_to_non_nullable
              as int?,
      minCtc: freezed == minCtc
          ? _self.minCtc
          : minCtc // ignore: cast_nullable_to_non_nullable
              as double?,
    ));
  }
}

// dart format on
