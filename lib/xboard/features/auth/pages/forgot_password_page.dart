import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:fl_clash/xboard/utils/xboard_notification.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_clash/xboard/features/shared/shared.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_clash/xboard/config/utils/config_file_loader.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/widgets/app_colors.dart';

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});
  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

enum ResetPasswordStep {
  sendCode, // 发送验证码步骤
  resetPassword // 重置密码步骤
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  ResetPasswordStep _currentStep = ResetPasswordStep.sendCode;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // 从配置文件加载的应用信息
  String _appTitle = 'XBoard';

  @override
  void initState() {
    super.initState();
    _loadAppInfo();
  }

  /// 加载应用信息（标题）
  Future<void> _loadAppInfo() async {
    final title = await ConfigFileLoaderHelper.getAppTitle();
    if (mounted) {
      setState(() {
        _appTitle = title;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _sendVerificationCode() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 使用 SDK 发送验证码
      await XBoardSDK.instance.auth.sendEmailVerifyCode(_emailController.text);

      if (mounted) {
        setState(() {
          _currentStep = ResetPasswordStep.resetPassword;
        });
        XBoardNotification.showSuccess(
            AppLocalizations.of(context).verificationCodeSent);
      }
    } catch (e) {
      if (mounted) {
        XBoardNotification.showError(
            '${AppLocalizations.of(context).sendCodeFailed}: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      XBoardNotification.showError(
          AppLocalizations.of(context).passwordMismatch);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 使用 SDK 重置密码
      final success = await XBoardSDK.instance.auth.forgotPassword(
        _emailController.text,
        _codeController.text,
        _passwordController.text,
      );

      if (!success) {
        throw Exception('重置密码失败');
      }

      if (mounted) {
        XBoardNotification.showSuccess(
            AppLocalizations.of(context).passwordResetSuccessful);
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        XBoardNotification.showError(
            '${AppLocalizations.of(context).passwordResetFailed}: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _goBackToSendCode() {
    setState(() {
      _currentStep = ResetPasswordStep.sendCode;
      _codeController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
    });
  }

  Widget _buildSendCodeStep({required bool isDesktop}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppLocalizations.of(context).enterEmailForReset,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 32),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: TextFormField(
              controller: _emailController,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
              decoration: InputDecoration(
                labelText: null,
                hintText: AppLocalizations.of(context).pleaseEnterEmail,
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.04),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 1.5,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 1.5,
                  ),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                prefixIcon: Icon(
                  Icons.email_outlined,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
              keyboardType: TextInputType.emailAddress,
              enabled: !_isLoading,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return AppLocalizations.of(context).pleaseEnterEmail;
                }
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                    .hasMatch(value)) {
                  return AppLocalizations.of(context).pleaseEnterValidEmail;
                }
                return null;
              },
            ),
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(
            onPressed: _isLoading ? null : _sendVerificationCode,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF5FD68A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    AppLocalizations.of(context).sendVerificationCode,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildResetPasswordStep({required bool isDesktop}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppLocalizations.of(context)
              .verificationCodeSentTo(_emailController.text),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 32),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: TextFormField(
              controller: _codeController,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
              decoration: InputDecoration(
                labelText: null,
                hintText:
                    AppLocalizations.of(context).pleaseEnterVerificationCode,
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.04),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 1.5,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 1.5,
                  ),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                prefixIcon: Icon(
                  Icons.verified_user_outlined,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
              keyboardType: TextInputType.number,
              enabled: !_isLoading,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return AppLocalizations.of(context)
                      .pleaseEnterVerificationCode;
                }
                if (value.length < 4) {
                  return AppLocalizations.of(context)
                      .pleaseEnterValidVerificationCode;
                }
                return null;
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
              decoration: InputDecoration(
                labelText: null,
                hintText: AppLocalizations.of(context).pleaseEnterNewPassword,
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.04),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 1.5,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 1.5,
                  ),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                prefixIcon: Icon(
                  Icons.lock_outlined,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
              enabled: !_isLoading,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return AppLocalizations.of(context).pleaseEnterNewPassword;
                }
                if (value.length < 6) {
                  return AppLocalizations.of(context).passwordMinLength;
                }
                return null;
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: TextFormField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirmPassword,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
              decoration: InputDecoration(
                labelText: null,
                hintText: AppLocalizations.of(context).pleaseConfirmNewPassword,
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.04),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 1.5,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 1.5,
                  ),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                prefixIcon: Icon(
                  Icons.lock_outlined,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureConfirmPassword = !_obscureConfirmPassword;
                    });
                  },
                ),
              ),
              enabled: !_isLoading,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return AppLocalizations.of(context).pleaseConfirmNewPassword;
                }
                if (value != _passwordController.text) {
                  return AppLocalizations.of(context).passwordMismatch;
                }
                return null;
              },
            ),
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(
            onPressed: _isLoading ? null : _resetPassword,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF5FD68A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    AppLocalizations.of(context).resetPassword,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: _isLoading ? null : _goBackToSendCode,
          child: Text(
            AppLocalizations.of(context).resendVerificationCode,
            style: const TextStyle(
              color: Color(0xFF409EFF),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 800) {
            return Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Container(
                    color: colorScheme.surface,
                    child: Stack(
                      children: [
                        Image.asset(
                          'assets/images/login_left_side.png',
                          fit: BoxFit.cover,
                          height: double.infinity,
                          width: double.infinity,
                        ),
                        Positioned(
                          left: 48,
                          bottom: 48,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _appTitle,
                                style: textTheme.displaySmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Let\'s start here!',
                                style: textTheme.headlineSmall?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Container(
                    color: Colors.white, // Right side background
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 48.0),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 400),
                          child: _buildForgotPasswordForm(context,
                              isDesktop: true),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          } else {
            // Mobile Layout - 深色模式紫色和海军蓝渐变
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return Container(
              decoration: AppColors.getBackgroundDecoration(),
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32.0, vertical: 24.0),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: _buildForgotPasswordForm(context, isDesktop: false),
                  ),
                ),
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildForgotPasswordForm(BuildContext context,
      {required bool isDesktop}) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Form(
      key: _formKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isDesktop) ...[
            Text(
              _currentStep == ResetPasswordStep.sendCode
                  ? AppLocalizations.of(context).resetPassword
                  : AppLocalizations.of(context).setNewPassword,
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 48),
          ] else ...[
            Center(
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFFF3D9A), // Pink
                          Color(0xFF9D5DFF), // Purple
                          Color(0xFF5DADFF), // Blue
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF9D5DFF).withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.lock_reset_outlined,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _currentStep == ResetPasswordStep.sendCode
                        ? AppLocalizations.of(context).resetPassword
                        : AppLocalizations.of(context).setNewPassword,
                    style: textTheme.displaySmall?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),
          ],
          if (_currentStep == ResetPasswordStep.sendCode)
            _buildSendCodeStep(isDesktop: isDesktop)
          else
            _buildResetPasswordStep(isDesktop: isDesktop),
          const SizedBox(height: 24),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                AppLocalizations.of(context).rememberPassword,
                style: textTheme.bodyMedium?.copyWith(
                  color: Colors.grey,
                ),
              ),
              TextButton(
                onPressed: () => context.pop(),
                child: Text(
                  AppLocalizations.of(context).backToLogin,
                  style: const TextStyle(
                    color: Color(0xFF409EFF),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
