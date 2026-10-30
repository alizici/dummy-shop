import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../core/network/api_failure.dart';
import '../data/auth_repository.dart';
import '../data/auth_user.dart';

enum LoginStatus { idle, submitting, success, failure }

class LoginState extends Equatable {
  const LoginState({this.status = LoginStatus.idle, this.failure, this.user});

  final LoginStatus status;
  final ApiFailure? failure;

  /// Set on success; the page hands it to the session.
  final AuthUser? user;

  @override
  List<Object?> get props => [status, failure, user];
}

class LoginCubit extends Cubit<LoginState> {
  LoginCubit(this._auth) : super(const LoginState());

  final AuthRepository _auth;

  Future<void> submit({required String username, required String password}) async {
    if (state.status == LoginStatus.submitting) return; // double taps
    emit(const LoginState(status: LoginStatus.submitting));
    try {
      final user = await _auth.login(username: username, password: password);
      if (isClosed) return;
      emit(LoginState(status: LoginStatus.success, user: user));
    } on ApiFailure catch (failure) {
      if (isClosed) return;
      emit(LoginState(status: LoginStatus.failure, failure: failure));
    }
  }
}
