import 'package:flutter/material.dart';

import 'package:xiaojia_ledger/core/theme.dart';
import 'package:xiaojia_ledger/modules/home/home_subtitle_repository.dart';
import 'package:xiaojia_ledger/widgets/unfinished_ring_mark.dart';

class HomeHeader extends StatelessWidget {
  final String subtitle;
  final VoidCallback onEditSubtitle;
  final VoidCallback onOpenSettings;

  const HomeHeader({
    super.key,
    required this.subtitle,
    required this.onEditSubtitle,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: KeyedSubtree(
                  key: const ValueKey('home-brand-mark'),
                  child: UnfinishedRingMark(
                    size: 34,
                    animate: true,
                    ringColor: AppColors.ink,
                    markerColor: AppColors.highlight,
                    trackColor: AppColors.ink.withAlpha(28),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 5),
                    SizedBox(
                      height: 24,
                      child: Text(
                        '小满记账',
                        key: const ValueKey('home-brand-title'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 20,
                          height: 1.2,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    SizedBox(
                      height: 20,
                      child: KeyedSubtree(
                        key: const ValueKey('home-subtitle-row'),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 24,
                              height: 20,
                              child: Center(
                                child: Icon(
                                  Icons.edit_outlined,
                                  key: const ValueKey(
                                    'home-signature-edit-icon',
                                  ),
                                  size: 13,
                                  color: AppColors.accent,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                key: const ValueKey('home-signature-text'),
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.2,
                                  color: AppColors.gray,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                key: const ValueKey('home-settings'),
                onPressed: onOpenSettings,
                constraints: const BoxConstraints.tightFor(
                  width: 48,
                  height: 48,
                ),
                icon: Icon(
                  Icons.settings_outlined,
                  size: 24,
                  color: AppColors.ink,
                ),
                tooltip: '设置',
              ),
            ],
          ),
          Positioned(
            left: 34 + AppSpacing.sm,
            top: 2,
            width: 48,
            height: 48,
            child: GestureDetector(
              key: const ValueKey('home-subtitle-edit'),
              onTap: onEditSubtitle,
              behavior: HitTestBehavior.opaque,
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }
}

class HomeSubtitleDialog extends StatefulWidget {
  final String initialValue;
  final Future<bool> Function(String value) onSave;

  const HomeSubtitleDialog({
    super.key,
    required this.initialValue,
    required this.onSave,
  });

  @override
  State<HomeSubtitleDialog> createState() => _HomeSubtitleDialogState();
}

class _HomeSubtitleDialogState extends State<HomeSubtitleDialog> {
  late final TextEditingController _controller;
  var _saving = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _errorText = null;
    });

    var saved = false;
    try {
      saved = await widget.onSave(_controller.text);
    } catch (_) {
      saved = false;
    }
    if (!mounted) return;

    if (saved) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _saving = false;
      _errorText = '保存失败，请重试';
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('编辑签名'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: HomeSubtitleRepository.maxLength,
        decoration: InputDecoration(
          hintText: HomeSubtitleRepository.defaultValue,
          errorText: _errorText,
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        TextButton(
          key: const ValueKey('home-subtitle-save'),
          onPressed: _saving ? null : _save,
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          child: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('保存'),
        ),
      ],
    );
  }
}
