class RegisterOutcome {
  final String? error;
  final String? pendingEmail;

  const RegisterOutcome._({this.error, this.pendingEmail});

  factory RegisterOutcome.success() => const RegisterOutcome._();

  factory RegisterOutcome.pending(String email) =>
      RegisterOutcome._(pendingEmail: email);

  factory RegisterOutcome.fail(String message) => RegisterOutcome._(error: message);

  bool get isSuccess => error == null && pendingEmail == null;
}
