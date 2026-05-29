// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'privacy_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PrivacyState {
  List<ConsentDto> get consents;
  bool get exportInProgress;
  Object? get mutationError;

  /// Create a copy of PrivacyState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $PrivacyStateCopyWith<PrivacyState> get copyWith =>
      _$PrivacyStateCopyWithImpl<PrivacyState>(
          this as PrivacyState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is PrivacyState &&
            const DeepCollectionEquality().equals(other.consents, consents) &&
            (identical(other.exportInProgress, exportInProgress) ||
                other.exportInProgress == exportInProgress) &&
            const DeepCollectionEquality()
                .equals(other.mutationError, mutationError));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(consents),
      exportInProgress,
      const DeepCollectionEquality().hash(mutationError));

  @override
  String toString() {
    return 'PrivacyState(consents: $consents, exportInProgress: $exportInProgress, mutationError: $mutationError)';
  }
}

/// @nodoc
abstract mixin class $PrivacyStateCopyWith<$Res> {
  factory $PrivacyStateCopyWith(
          PrivacyState value, $Res Function(PrivacyState) _then) =
      _$PrivacyStateCopyWithImpl;
  @useResult
  $Res call(
      {List<ConsentDto> consents,
      bool exportInProgress,
      Object? mutationError});
}

/// @nodoc
class _$PrivacyStateCopyWithImpl<$Res> implements $PrivacyStateCopyWith<$Res> {
  _$PrivacyStateCopyWithImpl(this._self, this._then);

  final PrivacyState _self;
  final $Res Function(PrivacyState) _then;

  /// Create a copy of PrivacyState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? consents = null,
    Object? exportInProgress = null,
    Object? mutationError = freezed,
  }) {
    return _then(_self.copyWith(
      consents: null == consents
          ? _self.consents
          : consents // ignore: cast_nullable_to_non_nullable
              as List<ConsentDto>,
      exportInProgress: null == exportInProgress
          ? _self.exportInProgress
          : exportInProgress // ignore: cast_nullable_to_non_nullable
              as bool,
      mutationError:
          freezed == mutationError ? _self.mutationError : mutationError,
    ));
  }
}

/// Adds pattern-matching-related methods to [PrivacyState].
extension PrivacyStatePatterns on PrivacyState {
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
    TResult Function(_PrivacyState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PrivacyState() when $default != null:
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
    TResult Function(_PrivacyState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PrivacyState():
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
    TResult? Function(_PrivacyState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PrivacyState() when $default != null:
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
    TResult Function(List<ConsentDto> consents, bool exportInProgress,
            Object? mutationError)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PrivacyState() when $default != null:
        return $default(
            _that.consents, _that.exportInProgress, _that.mutationError);
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
    TResult Function(List<ConsentDto> consents, bool exportInProgress,
            Object? mutationError)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PrivacyState():
        return $default(
            _that.consents, _that.exportInProgress, _that.mutationError);
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
    TResult? Function(List<ConsentDto> consents, bool exportInProgress,
            Object? mutationError)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PrivacyState() when $default != null:
        return $default(
            _that.consents, _that.exportInProgress, _that.mutationError);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _PrivacyState implements PrivacyState {
  const _PrivacyState(
      {required final List<ConsentDto> consents,
      this.exportInProgress = false,
      this.mutationError})
      : _consents = consents;

  final List<ConsentDto> _consents;
  @override
  List<ConsentDto> get consents {
    if (_consents is EqualUnmodifiableListView) return _consents;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_consents);
  }

  @override
  @JsonKey()
  final bool exportInProgress;
  @override
  final Object? mutationError;

  /// Create a copy of PrivacyState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$PrivacyStateCopyWith<_PrivacyState> get copyWith =>
      __$PrivacyStateCopyWithImpl<_PrivacyState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _PrivacyState &&
            const DeepCollectionEquality().equals(other._consents, _consents) &&
            (identical(other.exportInProgress, exportInProgress) ||
                other.exportInProgress == exportInProgress) &&
            const DeepCollectionEquality()
                .equals(other.mutationError, mutationError));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_consents),
      exportInProgress,
      const DeepCollectionEquality().hash(mutationError));

  @override
  String toString() {
    return 'PrivacyState(consents: $consents, exportInProgress: $exportInProgress, mutationError: $mutationError)';
  }
}

/// @nodoc
abstract mixin class _$PrivacyStateCopyWith<$Res>
    implements $PrivacyStateCopyWith<$Res> {
  factory _$PrivacyStateCopyWith(
          _PrivacyState value, $Res Function(_PrivacyState) _then) =
      __$PrivacyStateCopyWithImpl;
  @override
  @useResult
  $Res call(
      {List<ConsentDto> consents,
      bool exportInProgress,
      Object? mutationError});
}

/// @nodoc
class __$PrivacyStateCopyWithImpl<$Res>
    implements _$PrivacyStateCopyWith<$Res> {
  __$PrivacyStateCopyWithImpl(this._self, this._then);

  final _PrivacyState _self;
  final $Res Function(_PrivacyState) _then;

  /// Create a copy of PrivacyState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? consents = null,
    Object? exportInProgress = null,
    Object? mutationError = freezed,
  }) {
    return _then(_PrivacyState(
      consents: null == consents
          ? _self._consents
          : consents // ignore: cast_nullable_to_non_nullable
              as List<ConsentDto>,
      exportInProgress: null == exportInProgress
          ? _self.exportInProgress
          : exportInProgress // ignore: cast_nullable_to_non_nullable
              as bool,
      mutationError:
          freezed == mutationError ? _self.mutationError : mutationError,
    ));
  }
}

// dart format on
