import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/providers/business_provider.dart';
import '../../../core/providers/dashboard_provider.dart';
import '../../../core/providers/service_providers.dart';

class BusinessSetupPage extends ConsumerStatefulWidget {
  const BusinessSetupPage({super.key});

  @override
  ConsumerState<BusinessSetupPage> createState() =>
      _BusinessSetupPageState();
}

class _BusinessSetupPageState
    extends ConsumerState<BusinessSetupPage> {
  final _businessNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isCreating = false;
  bool _isSelectingBusiness = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _businessNameController.dispose();
    _ownerNameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _selectBusiness(String businessId) async {
    if (_isSelectingBusiness || _isCreating) {
      return;
    }

    setState(() {
      _isSelectingBusiness = true;
    });

    try {
      final userService = ref.read(userServiceProvider);

      final users = await userService.getUsers(
        businessId: businessId,
        activeOnly: true,
      );

      if (users.isEmpty) {
        throw StateError(
          'No active user exists for this business.',
        );
      }

      ref
          .read(activeBusinessIdProvider.notifier)
          .setBusinessId(businessId);

      ref
          .read(activeUserIdProvider.notifier)
          .setUserId(users.first.id);

      ref.invalidate(dashboardProvider);

      if (!mounted) {
        return;
      }

      context.go('/');
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to select business: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSelectingBusiness = false;
        });
      }
    }
  }

  Future<void> _createBusiness() async {
    if (_isCreating || _isSelectingBusiness) {
      return;
    }

    final businessName =
        _businessNameController.text.trim();
    final ownerName =
        _ownerNameController.text.trim();
    final username =
        _usernameController.text.trim();
    final password =
        _passwordController.text;
    final confirmPassword =
        _confirmPasswordController.text;

    if (businessName.isEmpty) {
      _showError('Please enter a business name.');
      return;
    }

    if (ownerName.isEmpty) {
      _showError('Please enter the owner name.');
      return;
    }

    if (username.isEmpty) {
      _showError('Please enter a username.');
      return;
    }

    if (password.length < 6) {
      _showError(
        'Password must contain at least 6 characters.',
      );
      return;
    }

    if (password != confirmPassword) {
      _showError('Passwords do not match.');
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      final businessService =
          ref.read(businessServiceProvider);
      final userService =
          ref.read(userServiceProvider);

      const uuid = Uuid();

      final businessId = uuid.v4();
      final userId = uuid.v4();

      final passwordHash = _hashPassword(password);

      await businessService.createBusiness(
        businessId: businessId,
        name: businessName,
      );

      await userService.createUser(
        userId: userId,
        businessId: businessId,
        name: ownerName,
        username: username,
        passwordHash: passwordHash,
        role: 'master_merchant',
      );

      ref
          .read(activeBusinessIdProvider.notifier)
          .setBusinessId(businessId);

      ref
          .read(activeUserIdProvider.notifier)
          .setUserId(userId);

      ref.invalidate(businessListProvider);
      ref.invalidate(dashboardProvider);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Business and owner account created successfully.',
          ),
        ),
      );

      context.go('/');
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to create business: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);

    return digest.toString();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final businessesAsync =
        ref.watch(businessListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Business Setup'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: businessesAsync.when(
          loading: () {
            return const Center(
              child: CircularProgressIndicator(),
            );
          },
          error: (error, stackTrace) {
            return Center(
              child: Text(
                'Unable to load businesses.\n$error',
                textAlign: TextAlign.center,
              ),
            );
          },
          data: (businesses) {
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your Businesses',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Select an existing business or create a new one.',
                  ),
                  const SizedBox(height: 24),

                  if (businesses.isNotEmpty)
                    ...businesses.map(
                      (business) {
                        return Card(
                          child: ListTile(
                            title: Text(business.name),
                            subtitle:
                                Text(business.currencyCode),
                            trailing: FilledButton(
                              onPressed:
                                  _isSelectingBusiness ||
                                          _isCreating
                                      ? null
                                      : () {
                                          _selectBusiness(
                                            business.id,
                                          );
                                        },
                              child: _isSelectingBusiness
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child:
                                          CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Select'),
                            ),
                          ),
                        );
                      },
                    ),

                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 24),

                  const Text(
                    'Create New Business',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'The first user will become the Master Merchant.',
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: 500,
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller:
                              _businessNameController,
                          decoration:
                              const InputDecoration(
                            labelText: 'Business name',
                            hintText:
                                'e.g. Khan General Store',
                          ),
                        ),
                        const SizedBox(height: 16),

                        TextField(
                          controller:
                              _ownerNameController,
                          decoration:
                              const InputDecoration(
                            labelText: 'Owner name',
                            hintText: 'e.g. Asif Khan',
                          ),
                        ),
                        const SizedBox(height: 16),

                        TextField(
                          controller:
                              _usernameController,
                          decoration:
                              const InputDecoration(
                            labelText: 'Username',
                            hintText: 'e.g. asif',
                          ),
                          textInputAction:
                              TextInputAction.next,
                        ),
                        const SizedBox(height: 16),

                        TextField(
                          controller:
                              _passwordController,
                          obscureText:
                              _obscurePassword,
                          decoration:
                              InputDecoration(
                            labelText: 'Password',
                            hintText:
                                'At least 6 characters',
                            suffixIcon:
                                IconButton(
                              onPressed: () {
                                setState(() {
                                  _obscurePassword =
                                      !_obscurePassword;
                                });
                              },
                              icon: Icon(
                                _obscurePassword
                                    ? Icons
                                        .visibility_outlined
                                    : Icons
                                        .visibility_off_outlined,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        TextField(
                          controller:
                              _confirmPasswordController,
                          obscureText:
                              _obscureConfirmPassword,
                          decoration:
                              InputDecoration(
                            labelText:
                                'Confirm password',
                            suffixIcon:
                                IconButton(
                              onPressed: () {
                                setState(() {
                                  _obscureConfirmPassword =
                                      !_obscureConfirmPassword;
                                });
                              },
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons
                                        .visibility_outlined
                                    : Icons
                                        .visibility_off_outlined,
                              ),
                            ),
                          ),
                          onSubmitted: (_) {
                            _createBusiness();
                          },
                        ),
                        const SizedBox(height: 20),

                        FilledButton.icon(
                          onPressed: _isCreating ||
                                  _isSelectingBusiness
                              ? null
                              : _createBusiness,
                          icon: _isCreating
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.add_business,
                                ),
                          label: Text(
                            _isCreating
                                ? 'Creating...'
                                : 'Create Business',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}