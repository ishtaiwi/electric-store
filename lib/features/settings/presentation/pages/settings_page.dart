import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/localization_service.dart';
import '../../../settings/domain/repositories/settings_repository.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../../core/di/injection_container.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _storeNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _taxRateController = TextEditingController();
  final _currencyController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  
  // User management state
  List<User> _users = [];
  bool _isLoadingUsers = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadUsers();
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _taxRateController.dispose();
    _currencyController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final repo = sl<SettingsRepository>();
      final settings = await repo.getSettings();
      
      _storeNameController.text = settings['store_name'] ?? '';
      _addressController.text = settings['address'] ?? '';
      _phoneController.text = settings['phone'] ?? '';
      _emailController.text = settings['email'] ?? '';
      _taxRateController.text = (settings['tax_rate'] ?? 0).toString();
      _currencyController.text = settings['currency'] ?? 'ILS';
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${LocalizationService().get('errorLoadingSettings')} $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final repo = sl<SettingsRepository>();
      await repo.updateSettings({
        'store_name': _storeNameController.text.trim(),
        'address': _addressController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'tax_rate': double.tryParse(_taxRateController.text) ?? 0,
        'currency': _currencyController.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(LocalizationService().get('settingsSaved')),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${LocalizationService().get('errorSavingSettings')} $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
    if (mounted) {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoadingUsers = true);
    try {
      final repo = sl<AuthRepository>();
      _users = await repo.getAllUsers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading users: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
    if (mounted) {
      setState(() => _isLoadingUsers = false);
    }
  }

  Future<void> _showAddUserDialog() async {
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final fullNameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(LocalizationService().get('addUser')),
          content: SizedBox(
            width: 400,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: usernameController,
                    decoration: InputDecoration(
                      labelText: LocalizationService().get('username'),
                      prefixIcon: const Icon(Icons.person),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return LocalizationService().get('usernameRequired');
                      }
                      if (_users.any((u) => u.username.toLowerCase() == value.trim().toLowerCase())) {
                        return LocalizationService().get('usernameExists');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: fullNameController,
                    decoration: InputDecoration(
                      labelText: LocalizationService().get('fullName'),
                      prefixIcon: const Icon(Icons.badge),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: LocalizationService().get('password'),
                      prefixIcon: const Icon(Icons.lock),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return LocalizationService().get('passwordRequired');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: confirmPasswordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: LocalizationService().get('confirmPassword'),
                      prefixIcon: const Icon(Icons.lock_outline),
                    ),
                    validator: (value) {
                      if (value != passwordController.text) {
                        return LocalizationService().get('passwordsDoNotMatch');
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(LocalizationService().get('cancel')),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  try {
                    final repo = sl<AuthRepository>();
                    await repo.createUser(User(
                      username: usernameController.text.trim(),
                      password: passwordController.text,
                      role: 'admin',
                      fullName: fullNameController.text.trim().isNotEmpty
                          ? fullNameController.text.trim()
                          : null,
                    ));
                    if (context.mounted) {
                      Navigator.pop(context, true);
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  }
                }
              },
              child: Text(LocalizationService().get('save')),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      await _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(LocalizationService().get('userCreated')),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  Future<void> _deleteUser(User user) async {
    // Prevent deleting the last admin
    if (_users.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LocalizationService().get('cannotDeleteLastAdmin')),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(LocalizationService().get('deleteUser')),
        content: Text(LocalizationService().get('confirmDeleteUser')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(LocalizationService().get('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: Text(LocalizationService().get('delete')),
          ),
        ],
      ),
    );

    if (confirmed == true && user.id != null) {
      try {
        final repo = sl<AuthRepository>();
        await repo.deleteUser(user.id!);
        await _loadUsers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(LocalizationService().get('userDeleted')),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                LocalizationService().get('settings'),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveSettings,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(LocalizationService().get('saveSettings')),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Settings Form
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Store Information Section
                          _SectionCard(
                            title: LocalizationService().get('storeInformation'),
                            icon: Icons.store,
                            children: [
                              TextFormField(
                                controller: _storeNameController,
                                decoration: InputDecoration(
                                  labelText: LocalizationService().get('storeName'),
                                  prefixIcon: const Icon(Icons.business),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return LocalizationService().get('storeNameRequired');
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _addressController,
                                decoration: InputDecoration(
                                  labelText: LocalizationService().get('address'),
                                  prefixIcon: const Icon(Icons.location_on),
                                ),
                                maxLines: 2,
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Contact Information Section
                          _SectionCard(
                            title: LocalizationService().get('contactInformation'),
                            icon: Icons.contact_phone,
                            children: [
                              TextFormField(
                                controller: _phoneController,
                                decoration: InputDecoration(
                                  labelText: LocalizationService().get('phone'),
                                  prefixIcon: const Icon(Icons.phone),
                                ),
                                keyboardType: TextInputType.phone,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _emailController,
                                decoration: InputDecoration(
                                  labelText: LocalizationService().get('email'),
                                  prefixIcon: const Icon(Icons.email),
                                ),
                                keyboardType: TextInputType.emailAddress,
                                validator: (value) {
                                  if (value != null && value.isNotEmpty) {
                                    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                                    if (!emailRegex.hasMatch(value)) {
                                      return LocalizationService().get('validEmail');
                                    }
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Financial Settings Section
                          _SectionCard(
                            title: LocalizationService().get('financialSettings'),
                            icon: Icons.attach_money,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _taxRateController,
                                      decoration: InputDecoration(
                                        labelText: LocalizationService().get('taxRatePercent'),
                                        prefixIcon: const Icon(Icons.percent),
                                      ),
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      validator: (value) {
                                        if (value != null && value.isNotEmpty) {
                                          final rate = double.tryParse(value);
                                          if (rate == null || rate < 0 || rate > 100) {
                                            return LocalizationService().get('taxRateRange');
                                          }
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _currencyController,
                                      decoration: InputDecoration(
                                        labelText: LocalizationService().get('currency'),
                                        prefixIcon: const Icon(Icons.currency_exchange),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.trim().isEmpty) {
                                          return LocalizationService().get('currencyRequired');
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Language Settings Section
                          _SectionCard(
                            title: LocalizationService().get('language'),
                            icon: Icons.language,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      LocalizationService().get('select_language'),
                                      style: Theme.of(context).textTheme.bodyLarge,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  SegmentedButton<String>(
                                    segments: const [
                                      ButtonSegment(
                                        value: 'en',
                                        label: Text('English'),
                                        icon: Icon(Icons.language),
                                      ),
                                      ButtonSegment(
                                        value: 'ar',
                                        label: Text('العربية'),
                                        icon: Icon(Icons.language),
                                      ),
                                    ],
                                    selected: {LocalizationService().currentLanguage},
                                    onSelectionChanged: (Set<String> selected) {
                                      setState(() {
                                        if (selected.first != LocalizationService().currentLanguage) {
                                          LocalizationService().toggleLanguage();
                                        }
                                      });
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                LocalizationService().get('languageApplied'),
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // User Management Section
                          _SectionCard(
                            title: LocalizationService().get('userManagement'),
                            icon: Icons.people,
                            children: [
                              Text(
                                LocalizationService().get('manageUsers'),
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: _showAddUserDialog,
                                    icon: const Icon(Icons.person_add),
                                    label: Text(LocalizationService().get('addUser')),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              if (_isLoadingUsers)
                                const Center(child: CircularProgressIndicator())
                              else if (_users.isEmpty)
                                Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Text(
                                      LocalizationService().get('noUsersFound'),
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                  ),
                                )
                              else
                                ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _users.length,
                                  separatorBuilder: (_, __) => const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final user = _users[index];
                                    return ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: AppColors.primary,
                                        child: const Icon(
                                          Icons.admin_panel_settings,
                                          color: Colors.white,
                                        ),
                                      ),
                                      title: Text(user.username),
                                      subtitle: user.fullName != null && user.fullName!.isNotEmpty
                                          ? Text(user.fullName!)
                                          : null,
                                      trailing: IconButton(
                                        icon: const Icon(Icons.delete, color: AppColors.error),
                                        onPressed: () => _deleteUser(user),
                                        tooltip: LocalizationService().get('deleteUser'),
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // System Information
                          _SectionCard(
                            title: LocalizationService().get('systemInformation'),
                            icon: Icons.info_outline,
                            children: [
                              _InfoRow(label: LocalizationService().get('appVersion'), value: '1.0.0'),
                              const Divider(height: 24),
                              _InfoRow(label: LocalizationService().get('database'), value: 'd.db (SQLite)'),
                              const Divider(height: 24),
                              _InfoRow(label: LocalizationService().get('platform'), value: LocalizationService().get('desktop')),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
