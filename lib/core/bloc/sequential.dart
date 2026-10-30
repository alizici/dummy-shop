import 'package:bloc/bloc.dart';

/// Handles events one at a time, in order.
///
/// A list that can be refreshed and paginated at the same time otherwise
/// races: a slow "next page" could land after a refresh and append items to
/// the wrong list. Processing events in sequence removes the race instead of
/// patching around it.
EventTransformer<E> sequential<E>() =>
    (events, mapper) => events.asyncExpand(mapper);
