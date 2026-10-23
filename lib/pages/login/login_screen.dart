import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lottie/lottie.dart';
import 'package:pinput/pinput.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:krpos/constants.dart';
import 'package:krpos/helpers/AppTheme.dart';
import 'package:krpos/locale/MyLocalizations.dart';
import 'package:krpos/helpers/SizeConfig.dart';

import 'view_model_manger/login_cubit.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    
    return BlocProvider(
      create: (context) => LoginCubit(),
      child: BlocConsumer<LoginCubit, LoginState>(
        listener: (context, state) {
          if (state is LoginFailed) {
            LoginCubit.get(context).isLoading = false;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: Colors.red,
                content: Text(
                  AppLocalizations.of(context).translate('invalid_credentials'),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            );
          } else if (state is LoginSuccessfully) {
            LoginCubit.get(context).navigateToHome(context);
          }
        },
        builder: (context, state) {
          var cubit = LoginCubit.get(context);
          return Scaffold(
            backgroundColor: Colors.white,
            body: Stack(
              children: [
                // Background Gradient Section
                Container(
                  height: size.height * 0.4,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF1A237E), // Deep Indigo
                        kDefaultColor,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(60),
                      bottomRight: Radius.circular(60),
                    ),
                  ),
                ),
                
                SafeArea(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        SizedBox(height: size.height * 0.05),
                        // Logo/Title Section
                        Lottie.asset(
                          'assets/lottie/welcome.json',
                          height: size.height * 0.15,
                        ),
                        Text(
                          'KR POS',
                          style: cubit.themeData.textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 30),
                        
                        // Main Login Card
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 450), // Limit width on large screens
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(32),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Form(
                                key: cubit.formKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      AppLocalizations.of(context).translate('login'),
                                      style: cubit.themeData.textTheme.headlineSmall?.copyWith(
                                        color: kDefaultColor,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Please sign in to continue',
                                      style: cubit.themeData.textTheme.bodyMedium?.copyWith(
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(height: 32),
                                    
                                    // Username Field
                                    _buildInputField(
                                      context: context,
                                      controller: cubit.usernameController,
                                      label: AppLocalizations.of(context).translate('username'),
                                      icon: Symbols.person,
                                      validator: (value) {
                                        if (value!.isEmpty) {
                                          return AppLocalizations.of(context).translate('please_enter_username');
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 20),
                                    
                                    // Password Field
                                    _buildInputField(
                                      context: context,
                                      controller: cubit.passwordController,
                                      label: AppLocalizations.of(context).translate('password'),
                                      icon: Symbols.lock,
                                      isPassword: true,
                                      obscureText: !cubit.passwordVisible,
                                      onToggleVisibility: () {
                                        cubit.passwordVisible = !cubit.passwordVisible;
                                      },
                                      suffixIcon: cubit.passwordIcon,
                                      validator: (value) {
                                        if (value!.isEmpty) {
                                          return AppLocalizations.of(context).translate('please_enter_password');
                                        }
                                        return null;
                                      },
                                    ),
                                    
                                    const SizedBox(height: 40),
                                    
                                    // Login Button
                                    SizedBox(
                                      width: double.infinity,
                                      height: 56,
                                      child: ElevatedButton(
                                        onPressed: cubit.isLoading ? null : () async {
                                          await cubit.checkOnLogin(context);
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: kDefaultColor,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          elevation: 4,
                                        ),
                                        child: cubit.isLoading 
                                          ? const CircularProgressIndicator(color: Colors.white)
                                          : Text(
                                              AppLocalizations.of(context).translate('login').toUpperCase(),
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 1.2,
                                              ),
                                            ),
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    // Fast Login Options
                                    FutureBuilder<bool>(
                                      future: cubit.hasFastLoginData(),
                                      builder: (context, snapshot) {
                                        if (snapshot.data == true) {
                                          return Column(
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Container(
                                                      width: 40,
                                                      height: 1,
                                                      color: Colors.grey[300]),
                                                  const Padding(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                            horizontal: 16),
                                                    child: Text("Fast Login",
                                                        style: TextStyle(
                                                            color: Colors.grey,
                                                            fontSize: 12)),
                                                  ),
                                                  Container(
                                                      width: 40,
                                                      height: 1,
                                                      color: Colors.grey[300]),
                                                ],
                                              ),
                                              const SizedBox(height: 16),
                                              FutureBuilder<List<String>>(
                                                future: cubit.getFastLoginUsers(),
                                                builder: (context, usersSnapshot) {
                                                  if (usersSnapshot.hasData && usersSnapshot.data!.length > 1) {
                                                    return Padding(
                                                      padding: const EdgeInsets.only(bottom: 16),
                                                      child: SingleChildScrollView(
                                                        scrollDirection: Axis.horizontal,
                                                        child: Row(
                                                          children: usersSnapshot.data!.map((user) {
                                                            bool isSelected = cubit.usernameController.text == user;
                                                            return Padding(
                                                              padding: const EdgeInsets.symmetric(horizontal: 4),
                                                              child: ActionChip(
                                                                label: Text(user, style: TextStyle(color: isSelected ? Colors.white : kDefaultColor)),
                                                                backgroundColor: isSelected ? kDefaultColor : Colors.grey[100],
                                                                onPressed: () => cubit.selectUserForFastLogin(user),
                                                              ),
                                                            );
                                                          }).toList(),
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                  return const SizedBox.shrink();
                                                },
                                              ),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.spaceEvenly,
                                                children: [
                                                  _buildFastLoginBtn(
                                                    icon: Symbols.fingerprint,
                                                    label: "Biometric",
                                                    onTap: () => cubit
                                                        .authenticateWithBiometrics(
                                                            context),
                                                  ),
                                                  _buildFastLoginBtn(
                                                    icon: Symbols.dialpad,
                                                    label: "PIN Login",
                                                    onTap: () =>
                                                        _showPinDialog(
                                                            context, cubit),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          );
                                        }
                                        return const SizedBox.shrink();
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 40),
                        
                        // Footer Section
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              AppLocalizations.of(context).translate('no_account'),
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                            TextButton(
                              onPressed: () async => await cubit.register(),
                              child: Text(
                                AppLocalizations.of(context).translate('register'),
                                style: const TextStyle(
                                  color: kDefaultColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputField({
    required BuildContext context,
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onToggleVisibility,
    IconData? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          validator: validator,
          style: const TextStyle(fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
            prefixIcon: Icon(icon, color: kDefaultColor, size: 22),
            suffixIcon: isPassword 
              ? IconButton(
                  icon: Icon(suffixIcon, color: Colors.grey[400], size: 22),
                  onPressed: onToggleVisibility,
                )
              : null,
            filled: true,
            fillColor: Colors.grey[50],
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: kDefaultColor, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.red, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildFastLoginBtn({required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: kDefaultColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: kDefaultColor, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 10, color: kDefaultColor, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showPinDialog(BuildContext context, LoginCubit cubit) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Enter PIN", textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Pinput(
              length: 4,
              obscureText: true,
              autofocus: true,
              onCompleted: (pin) {
                Navigator.pop(context);
                cubit.loginWithPin(context, pin);
              },
            ),
          ],
        ),
      ),
    );
  }
}
