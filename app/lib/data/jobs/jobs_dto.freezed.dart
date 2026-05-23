// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'jobs_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$JobDetailDto {
  JobSummaryDto get job;
  EmployerSummaryDto get employer;
  MatchSummaryDto? get match;
  ApplicationDto? get application;
  SavedJobDto? get savedJob;

  /// Create a copy of JobDetailDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $JobDetailDtoCopyWith<JobDetailDto> get copyWith =>
      _$JobDetailDtoCopyWithImpl<JobDetailDto>(
          this as JobDetailDto, _$identity);

  /// Serializes this JobDetailDto to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is JobDetailDto &&
            (identical(other.job, job) || other.job == job) &&
            (identical(other.employer, employer) ||
                other.employer == employer) &&
            (identical(other.match, match) || other.match == match) &&
            (identical(other.application, application) ||
                other.application == application) &&
            (identical(other.savedJob, savedJob) ||
                other.savedJob == savedJob));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, job, employer, match, application, savedJob);

  @override
  String toString() {
    return 'JobDetailDto(job: $job, employer: $employer, match: $match, application: $application, savedJob: $savedJob)';
  }
}

/// @nodoc
abstract mixin class $JobDetailDtoCopyWith<$Res> {
  factory $JobDetailDtoCopyWith(
          JobDetailDto value, $Res Function(JobDetailDto) _then) =
      _$JobDetailDtoCopyWithImpl;
  @useResult
  $Res call(
      {JobSummaryDto job,
      EmployerSummaryDto employer,
      MatchSummaryDto? match,
      ApplicationDto? application,
      SavedJobDto? savedJob});
}

/// @nodoc
class _$JobDetailDtoCopyWithImpl<$Res> implements $JobDetailDtoCopyWith<$Res> {
  _$JobDetailDtoCopyWithImpl(this._self, this._then);

  final JobDetailDto _self;
  final $Res Function(JobDetailDto) _then;

  /// Create a copy of JobDetailDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? job = null,
    Object? employer = null,
    Object? match = freezed,
    Object? application = freezed,
    Object? savedJob = freezed,
  }) {
    return _then(_self.copyWith(
      job: null == job
          ? _self.job
          : job // ignore: cast_nullable_to_non_nullable
              as JobSummaryDto,
      employer: null == employer
          ? _self.employer
          : employer // ignore: cast_nullable_to_non_nullable
              as EmployerSummaryDto,
      match: freezed == match
          ? _self.match
          : match // ignore: cast_nullable_to_non_nullable
              as MatchSummaryDto?,
      application: freezed == application
          ? _self.application
          : application // ignore: cast_nullable_to_non_nullable
              as ApplicationDto?,
      savedJob: freezed == savedJob
          ? _self.savedJob
          : savedJob // ignore: cast_nullable_to_non_nullable
              as SavedJobDto?,
    ));
  }
}

/// Adds pattern-matching-related methods to [JobDetailDto].
extension JobDetailDtoPatterns on JobDetailDto {
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
    TResult Function(_JobDetailDto value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _JobDetailDto() when $default != null:
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
    TResult Function(_JobDetailDto value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _JobDetailDto():
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
    TResult? Function(_JobDetailDto value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _JobDetailDto() when $default != null:
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
    TResult Function(
            JobSummaryDto job,
            EmployerSummaryDto employer,
            MatchSummaryDto? match,
            ApplicationDto? application,
            SavedJobDto? savedJob)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _JobDetailDto() when $default != null:
        return $default(_that.job, _that.employer, _that.match,
            _that.application, _that.savedJob);
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
    TResult Function(
            JobSummaryDto job,
            EmployerSummaryDto employer,
            MatchSummaryDto? match,
            ApplicationDto? application,
            SavedJobDto? savedJob)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _JobDetailDto():
        return $default(_that.job, _that.employer, _that.match,
            _that.application, _that.savedJob);
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
    TResult? Function(
            JobSummaryDto job,
            EmployerSummaryDto employer,
            MatchSummaryDto? match,
            ApplicationDto? application,
            SavedJobDto? savedJob)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _JobDetailDto() when $default != null:
        return $default(_that.job, _that.employer, _that.match,
            _that.application, _that.savedJob);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _JobDetailDto implements JobDetailDto {
  const _JobDetailDto(
      {required this.job,
      required this.employer,
      this.match,
      this.application,
      this.savedJob});
  factory _JobDetailDto.fromJson(Map<String, dynamic> json) =>
      _$JobDetailDtoFromJson(json);

  @override
  final JobSummaryDto job;
  @override
  final EmployerSummaryDto employer;
  @override
  final MatchSummaryDto? match;
  @override
  final ApplicationDto? application;
  @override
  final SavedJobDto? savedJob;

  /// Create a copy of JobDetailDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$JobDetailDtoCopyWith<_JobDetailDto> get copyWith =>
      __$JobDetailDtoCopyWithImpl<_JobDetailDto>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$JobDetailDtoToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _JobDetailDto &&
            (identical(other.job, job) || other.job == job) &&
            (identical(other.employer, employer) ||
                other.employer == employer) &&
            (identical(other.match, match) || other.match == match) &&
            (identical(other.application, application) ||
                other.application == application) &&
            (identical(other.savedJob, savedJob) ||
                other.savedJob == savedJob));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, job, employer, match, application, savedJob);

  @override
  String toString() {
    return 'JobDetailDto(job: $job, employer: $employer, match: $match, application: $application, savedJob: $savedJob)';
  }
}

/// @nodoc
abstract mixin class _$JobDetailDtoCopyWith<$Res>
    implements $JobDetailDtoCopyWith<$Res> {
  factory _$JobDetailDtoCopyWith(
          _JobDetailDto value, $Res Function(_JobDetailDto) _then) =
      __$JobDetailDtoCopyWithImpl;
  @override
  @useResult
  $Res call(
      {JobSummaryDto job,
      EmployerSummaryDto employer,
      MatchSummaryDto? match,
      ApplicationDto? application,
      SavedJobDto? savedJob});
}

/// @nodoc
class __$JobDetailDtoCopyWithImpl<$Res>
    implements _$JobDetailDtoCopyWith<$Res> {
  __$JobDetailDtoCopyWithImpl(this._self, this._then);

  final _JobDetailDto _self;
  final $Res Function(_JobDetailDto) _then;

  /// Create a copy of JobDetailDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? job = null,
    Object? employer = null,
    Object? match = freezed,
    Object? application = freezed,
    Object? savedJob = freezed,
  }) {
    return _then(_JobDetailDto(
      job: null == job
          ? _self.job
          : job // ignore: cast_nullable_to_non_nullable
              as JobSummaryDto,
      employer: null == employer
          ? _self.employer
          : employer // ignore: cast_nullable_to_non_nullable
              as EmployerSummaryDto,
      match: freezed == match
          ? _self.match
          : match // ignore: cast_nullable_to_non_nullable
              as MatchSummaryDto?,
      application: freezed == application
          ? _self.application
          : application // ignore: cast_nullable_to_non_nullable
              as ApplicationDto?,
      savedJob: freezed == savedJob
          ? _self.savedJob
          : savedJob // ignore: cast_nullable_to_non_nullable
              as SavedJobDto?,
    ));
  }
}

// dart format on
