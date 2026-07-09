class CompleteRegisterRequest {
  const CompleteRegisterRequest({
    required this.email,
    required this.password,
    required this.mobile,
    required this.sex,
    required this.age,
    required this.marketingOptIn,
  });

  final String email;
  final String password;
  final String mobile;
  final String sex;
  final int age;
  final bool marketingOptIn;

  Map<String, dynamic> toJson() => {
    'email': email,
    'password': password,
    'mobile': mobile,
    'sex': sex,
    'age': age,
    'marketing_opt_in': marketingOptIn,
  };
}
