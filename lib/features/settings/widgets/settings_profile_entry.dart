import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:novella/data/services/user_profile_service.dart';

enum _AvatarInputType { directUrl, qqAvatar, qqGroupAvatar }

class SettingsProfileEntry extends StatefulWidget {
  const SettingsProfileEntry({super.key});

  @override
  State<SettingsProfileEntry> createState() => _SettingsProfileEntryState();
}

class _SettingsProfileEntryState extends State<SettingsProfileEntry> {
  final _profileService = UserProfileService();

  UserProfile? _profile;
  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        _loading = true;
      });
    }

    try {
      final profile = await _profileService.getMyInfo(
        requestScope: 'settings_profile',
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _profile = profile;
        _errorMessage = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _profile = null;
        _errorMessage = _formatError(error);
        _loading = false;
      });
    }
  }

  String _formatError(Object error) {
    final rawMessage = error.toString().trim();
    if (rawMessage.isEmpty) {
      return '加载个人资料失败，请重试';
    }

    const prefix = 'Exception:';
    final normalizedMessage =
        rawMessage.startsWith(prefix)
            ? rawMessage.substring(prefix.length).trim()
            : rawMessage;
    return normalizedMessage.isEmpty ? '加载个人资料失败，请重试' : normalizedMessage;
  }

  Future<void> _handleTap() async {
    if (_loading) {
      return;
    }

    final currentProfile = _profile;
    if (currentProfile != null) {
      await _showProfileSheet(currentProfile);
      return;
    }

    await _loadProfile();
    if (!mounted) {
      return;
    }

    final refreshedProfile = _profile;
    if (refreshedProfile != null) {
      await _showProfileSheet(refreshedProfile);
      return;
    }

    await _showLoadFailedSheet();
  }

  Future<void> _showLoadFailedSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final textTheme = Theme.of(sheetContext).textTheme;
        final colorScheme = Theme.of(sheetContext).colorScheme;

        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Text(
                  '个人资料',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  _errorMessage ?? '加载个人资料失败，请重试',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.refresh_rounded),
                title: const Text('重新获取资料'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _loadProfile();
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showProfileSheet(UserProfile profile) async {
    String? copiedFieldKey;
    var copyFeedbackToken = 0;

    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final colorScheme = Theme.of(sheetContext).colorScheme;
        final textTheme = Theme.of(sheetContext).textTheme;

        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            Future<void> handleCopy(String fieldKey, String value) async {
              final trimmedValue = value.trim();
              if (trimmedValue.isEmpty) {
                return;
              }

              await Clipboard.setData(ClipboardData(text: trimmedValue));
              if (!sheetContext.mounted) {
                return;
              }

              final nextToken = copyFeedbackToken + 1;
              setSheetState(() {
                copiedFieldKey = fieldKey;
                copyFeedbackToken = nextToken;
              });

              Future<void>.delayed(const Duration(milliseconds: 1200)).then((
                _,
              ) {
                if (!sheetContext.mounted ||
                    copyFeedbackToken != nextToken ||
                    copiedFieldKey != fieldKey) {
                  return;
                }

                setSheetState(() {
                  copiedFieldKey = null;
                });
              });
            }

            final inviteCode =
                profile.inviteCode.trim().isEmpty
                    ? '暂无'
                    : _maskValue(profile.inviteCode.trim());

            return SafeArea(
              top: false,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Text(
                        '个人资料',
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Text(
                        '长按可复制部分账号信息',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap:
                              () => _handleAvatarEditTap(profile, sheetContext),
                          child: Ink(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                _ProfileAvatar(
                                  avatarUrl: profile.avatar,
                                  name: profile.userName,
                                  radius: 28,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _displayValue(profile.userName),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        profile.email.trim().isNotEmpty
                                            ? profile.email.trim()
                                            : _displayValue(profile.groupName),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: textTheme.bodySmall?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Icon(
                                  Icons.chevron_right,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    _ProfileInfoTile(
                      icon: Icons.badge_outlined,
                      label: 'UID',
                      value: '${profile.id}',
                      trailing: _CopySuccessIndicator(
                        visible: copiedFieldKey == 'uid',
                      ),
                      onLongPress: () => handleCopy('uid', '${profile.id}'),
                    ),
                    _ProfileInfoTile(
                      icon: Icons.person_outline_rounded,
                      label: '昵称',
                      value: _displayValue(profile.userName),
                      trailing: _CopySuccessIndicator(
                        visible: copiedFieldKey == 'user_name',
                      ),
                      onLongPress:
                          () => handleCopy('user_name', profile.userName),
                    ),
                    _ProfileInfoTile(
                      icon: Icons.email_outlined,
                      label: '邮箱',
                      value: _displayValue(profile.email),
                      trailing: _CopySuccessIndicator(
                        visible: copiedFieldKey == 'email',
                      ),
                      onLongPress: () => handleCopy('email', profile.email),
                    ),
                    _ProfileInfoTile(
                      icon: Icons.vpn_key_outlined,
                      label: '邀请码',
                      value: inviteCode,
                      trailing: _CopySuccessIndicator(
                        visible: copiedFieldKey == 'invite_code',
                      ),
                      onLongPress:
                          profile.inviteCode.trim().isEmpty
                              ? null
                              : () =>
                                  handleCopy('invite_code', profile.inviteCode),
                    ),
                    _ProfileInfoTile(
                      icon: Icons.groups_outlined,
                      label: '用户组',
                      value: _displayValue(profile.groupName),
                    ),
                    _ProfileInfoTile(
                      icon: Icons.stars_outlined,
                      label: '积分',
                      value: '${profile.point}',
                    ),
                    _ProfileInfoTile(
                      icon: Icons.event_outlined,
                      label: '注册时间',
                      value: _formatDate(profile.registerAt),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleAvatarEditTap(
    UserProfile profile,
    BuildContext sheetContext,
  ) async {
    Navigator.pop(sheetContext);
    await Future<void>.delayed(const Duration(milliseconds: 180));

    final changed = await _showAvatarEditSheet(profile);
    if (changed != true || !mounted) {
      return;
    }

    await _loadProfile(silent: true);
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('头像已更新'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<bool?> _showAvatarEditSheet(UserProfile profile) {
    return showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder:
          (sheetContext) => _AvatarEditSheet(
            profile: profile,
            onSubmit:
                (avatarUrl) => _profileService.setAvatar(
                  avatarUrl,
                  requestScope: 'settings_profile',
                ),
          ),
    );
  }

  String _maskValue(String value) {
    if (value.isEmpty) {
      return '暂无';
    }
    return value.replaceAll(RegExp(r'.'), '*');
  }

  String _displayValue(String value) {
    final trimmedValue = value.trim();
    return trimmedValue.isEmpty ? '暂无' : trimmedValue;
  }

  String _formatDate(DateTime? value) {
    if (value == null) {
      return '暂无';
    }

    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: _handleTap,
      tooltip: '个人资料',
      icon: const Icon(Icons.person_outline_rounded),
    );
  }
}

class _ProfileInfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;
  final VoidCallback? onLongPress;

  const _ProfileInfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(value),
      trailing: trailing,
      onLongPress: onLongPress,
    );
  }
}

class _CopySuccessIndicator extends StatelessWidget {
  final bool visible;

  const _CopySuccessIndicator({required this.visible});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: 24,
      height: 24,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child:
            visible
                ? Icon(
                  key: const ValueKey('visible'),
                  Icons.check_rounded,
                  size: 20,
                  color: colorScheme.primary,
                )
                : const SizedBox(key: ValueKey('hidden')),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  final String avatarUrl;
  final String name;
  final double radius;

  const _ProfileAvatar({
    required this.avatarUrl,
    required this.name,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final trimmedName = name.trim();
    final avatarText = trimmedName.isEmpty ? '' : trimmedName.substring(0, 1);
    final fallbackAvatar = CircleAvatar(
      radius: radius,
      backgroundColor: colorScheme.surfaceContainerHighest,
      child:
          avatarText.isEmpty
              ? Icon(
                Icons.person_outline_rounded,
                size: radius * 0.95,
                color: colorScheme.onSurfaceVariant,
              )
              : Text(
                avatarText,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: radius * 0.8,
                ),
              ),
    );

    if (avatarUrl.trim().isEmpty) {
      return fallbackAvatar;
    }

    final avatarSize = radius * 2;
    return SizedBox(
      width: avatarSize,
      height: avatarSize,
      child: CachedNetworkImage(
        imageUrl: avatarUrl,
        memCacheWidth: (avatarSize * 4).round(),
        imageBuilder:
            (context, imageProvider) =>
                CircleAvatar(radius: radius, backgroundImage: imageProvider),
        placeholder: (context, url) => fallbackAvatar,
        errorWidget: (context, url, error) => fallbackAvatar,
      ),
    );
  }
}

class _AvatarEditSheet extends StatefulWidget {
  final UserProfile profile;
  final Future<void> Function(String avatarUrl) onSubmit;

  const _AvatarEditSheet({required this.profile, required this.onSubmit});

  @override
  State<_AvatarEditSheet> createState() => _AvatarEditSheetState();
}

class _AvatarEditSheetState extends State<_AvatarEditSheet> {
  static final httpsReg = RegExp(
    r'https:\/\/[\w\-_]+(\.[\w\-_]+)+([\w\-.,@?^=%&:/~+#]*[\w\-@?^=%&/~+#])?',
  );
  static final qqReg = RegExp(r'^[1-9]\d{4,}$');
  static final qqAvatarReg = RegExp(
    r'https:\/\/q\.qlogo\.cn\/headimg_dl\?spec=100&dst_uin=',
  );
  static final qqGroupAvatarReg = RegExp(
    r'https:\/\/p\.qlogo\.cn\/gh\/([0-9]*)\/([0-9]*)\/100',
  );

  static const qqAvatarUrl = 'https://q.qlogo.cn/headimg_dl?spec=100&dst_uin=';
  static const qqGroupAvatarUrl =
      'https://p.qlogo.cn/gh/{group_num}/{group_num}/100';

  final TextEditingController _valueController = TextEditingController();
  final Map<_AvatarInputType, String> _draftValues = {
    _AvatarInputType.directUrl: '',
    _AvatarInputType.qqAvatar: '',
    _AvatarInputType.qqGroupAvatar: '',
  };

  _AvatarInputType _inputType = _AvatarInputType.directUrl;
  bool _saving = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _hydrateInitialValue();
  }

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  void _hydrateInitialValue() {
    final avatar = widget.profile.avatar.trim();
    if (qqAvatarReg.hasMatch(avatar)) {
      _inputType = _AvatarInputType.qqAvatar;
      _draftValues[_AvatarInputType.qqAvatar] = avatar.replaceFirst(
        qqAvatarUrl,
        '',
      );
      _syncController();
      return;
    }

    final qqGroupMatch = qqGroupAvatarReg.firstMatch(avatar);
    if (qqGroupMatch != null) {
      _inputType = _AvatarInputType.qqGroupAvatar;
      _draftValues[_AvatarInputType.qqGroupAvatar] =
          qqGroupMatch.group(1) ?? '';
      _syncController();
      return;
    }

    _inputType = _AvatarInputType.directUrl;
    _draftValues[_AvatarInputType.directUrl] = avatar;
    _syncController();
  }

  void _syncController() {
    final value = _draftValues[_inputType] ?? '';
    _valueController.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  void _switchInputType(_AvatarInputType nextType) {
    if (_inputType == nextType) {
      return;
    }

    setState(() {
      _draftValues[_inputType] = _valueController.text;
      _inputType = nextType;
      _errorText = null;
      _syncController();
    });
  }

  String get _previewUrl {
    final raw = _valueController.text.trim();
    if (raw.isEmpty) {
      return widget.profile.avatar;
    }

    switch (_inputType) {
      case _AvatarInputType.directUrl:
        return raw;
      case _AvatarInputType.qqAvatar:
        return '$qqAvatarUrl$raw';
      case _AvatarInputType.qqGroupAvatar:
        return qqGroupAvatarUrl.replaceAll('{group_num}', raw);
    }
  }

  String get _fieldLabel {
    switch (_inputType) {
      case _AvatarInputType.directUrl:
        return '图片 URL';
      case _AvatarInputType.qqAvatar:
        return 'QQ 号';
      case _AvatarInputType.qqGroupAvatar:
        return 'QQ 群号';
    }
  }

  String get _fieldHint {
    switch (_inputType) {
      case _AvatarInputType.directUrl:
        return '请输入图片URL';
      case _AvatarInputType.qqAvatar:
        return '请输入 QQ 号';
      case _AvatarInputType.qqGroupAvatar:
        return '请输入 QQ 群号';
    }
  }

  String get _modeHint {
    switch (_inputType) {
      case _AvatarInputType.directUrl:
        return '图片 URL 仅支持 https';
      case _AvatarInputType.qqAvatar:
        return '使用此功能会导致你的 QQ 号暴露，但可以实时同步你的 QQ 头像';
      case _AvatarInputType.qqGroupAvatar:
        return '使用此功能会导致你的 QQ 群号暴露，但可以实时同步 QQ 群头像';
    }
  }

  String _formatSubmitError(Object error) {
    final rawMessage = error.toString().trim();
    if (rawMessage.isEmpty) {
      return '保存失败，请重试';
    }

    const prefix = 'Exception:';
    final normalizedMessage =
        rawMessage.startsWith(prefix)
            ? rawMessage.substring(prefix.length).trim()
            : rawMessage;
    return normalizedMessage.isEmpty ? '保存失败，请重试' : normalizedMessage;
  }

  Future<void> _submit() async {
    final raw = _valueController.text.trim();
    late final String avatarUrl;

    switch (_inputType) {
      case _AvatarInputType.directUrl:
        if (!httpsReg.hasMatch(raw)) {
          setState(() {
            _errorText = '请输入正确的图片URL';
          });
          return;
        }
        avatarUrl = raw;
        break;
      case _AvatarInputType.qqAvatar:
        if (!qqReg.hasMatch(raw)) {
          setState(() {
            _errorText = '请输入正确的 QQ 号';
          });
          return;
        }
        avatarUrl = '$qqAvatarUrl$raw';
        break;
      case _AvatarInputType.qqGroupAvatar:
        if (!qqReg.hasMatch(raw)) {
          setState(() {
            _errorText = '请输入正确的 QQ 群号';
          });
          return;
        }
        avatarUrl = qqGroupAvatarUrl.replaceAll('{group_num}', raw);
        break;
    }

    setState(() {
      _saving = true;
      _errorText = null;
    });

    try {
      await widget.onSubmit(avatarUrl);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = _formatSubmitError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                '修改头像',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(
              '选择头像来源后填写内容',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.55,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  _ProfileAvatar(
                    avatarUrl: _previewUrl,
                    name: widget.profile.userName,
                    radius: 28,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.profile.userName.trim().isEmpty
                              ? '个人头像'
                              : widget.profile.userName.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '实时预览头像效果',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<_AvatarInputType>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment<_AvatarInputType>(
                    value: _AvatarInputType.directUrl,
                    label: Text('普通 URL'),
                  ),
                  ButtonSegment<_AvatarInputType>(
                    value: _AvatarInputType.qqAvatar,
                    label: Text('QQ 头像'),
                  ),
                  ButtonSegment<_AvatarInputType>(
                    value: _AvatarInputType.qqGroupAvatar,
                    label: Text('QQ 群头像'),
                  ),
                ],
                selected: <_AvatarInputType>{_inputType},
                onSelectionChanged:
                    _saving
                        ? null
                        : (selection) {
                          if (selection.isEmpty) {
                            return;
                          }
                          _switchInputType(selection.first);
                        },
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _valueController,
              enabled: !_saving,
              decoration: InputDecoration(
                labelText: _fieldLabel,
                hintText: _fieldHint,
                errorText: _errorText,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) {
                _draftValues[_inputType] = _valueController.text;
                if (_errorText != null) {
                  setState(() {
                    _errorText = null;
                  });
                } else {
                  setState(() {});
                }
              },
            ),
            const SizedBox(height: 10),
            Text(
              _modeHint,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _saving ? null : () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _saving ? null : _submit,
                    child:
                        _saving
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Text('保存'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
