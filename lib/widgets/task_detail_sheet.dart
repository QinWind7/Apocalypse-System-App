import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/system_task.dart';
import '../theme.dart';

/// 任务详情底部弹层：执行建议、时间与提醒、学习资源、编辑与完成。
class TaskDetailSheet extends StatefulWidget {
  const TaskDetailSheet({
    super.key,
    required this.task,
    required this.completed,
    required this.onComplete,
    required this.onUpdated,
  });

  final SystemTask task;
  final bool completed;
  final VoidCallback onComplete;
  final ValueChanged<SystemTask> onUpdated;

  @override
  State<TaskDetailSheet> createState() => _TaskDetailSheetState();
}

class _TaskDetailSheetState extends State<TaskDetailSheet> {
  late SystemTask _task = widget.task;
  late final TextEditingController _titleController =
      TextEditingController(text: _task.title);
  late final TextEditingController _descriptionController =
      TextEditingController(text: _task.detailDescription);
  late final TextEditingController _timeController =
      TextEditingController(text: _task.recommendedTime);

  bool _pressed = false;
  bool _editing = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  void _handleComplete() {
    if (widget.completed) return;
    HapticFeedback.mediumImpact();
    widget.onComplete();
  }

  void _startEditing() {
    _titleController.text = _task.title;
    _descriptionController.text = _task.detailDescription;
    _timeController.text = _task.recommendedTime;
    setState(() => _editing = true);
  }

  void _cancelEditing() {
    FocusScope.of(context).unfocus();
    setState(() => _editing = false);
  }

  void _saveEditing() {
    final title = _titleController.text.trim();
    final updated = _task.copyWith(
      title: title.isEmpty ? _task.title : title,
      detailDescription: _descriptionController.text.trim(),
      recommendedTime: _timeController.text.trim(),
    );

    setState(() {
      _task = updated;
      _editing = false;
    });
    widget.onUpdated(updated);
    FocusScope.of(context).unfocus();
  }

  void _toggleReminder(bool value) {
    final updated = _task.copyWith(isReminderOn: value);
    setState(() => _task = updated);
    widget.onUpdated(updated);
  }

  Future<void> _openResource() async {
    final uri = Uri.tryParse(_task.resourceUrl);
    if (uri == null) return;

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) _showMessage('无法打开学习资料链接');
    } catch (_) {
      if (mounted) _showMessage('无法打开学习资料链接');
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.82,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(28),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: widget.completed
                              ? AppColors.surfaceMuted
                              : AppColors.accentSoft,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _task.category,
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 0.8,
                            fontWeight: FontWeight.w500,
                            color: widget.completed
                                ? AppColors.textTertiary
                                : AppColors.accent,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'TASK ${_task.code}',
                        style: const TextStyle(
                          fontSize: 9.5,
                          letterSpacing: 1.2,
                          color: AppColors.textTertiary,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _editing ? _cancelEditing : _startEditing,
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            _editing
                                ? Icons.close_rounded
                                : Icons.edit_outlined,
                            size: 18,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_editing)
                    _buildEditContent()
                  else
                    _buildViewContent(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildViewContent() {
    final description = _task.detailDescription.trim().isEmpty
        ? _task.detail
        : _task.detailDescription;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _task.title,
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: const TextStyle(
            fontSize: 12.5,
            height: 1.65,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.only(left: 12, right: 4),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                size: 14,
                color: AppColors.accent,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _task.recommendedTime.isEmpty
                      ? '未设置推荐时间'
                      : _task.recommendedTime,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontFamily: 'monospace',
                    color: _task.recommendedTime.isEmpty
                        ? AppColors.textTertiary
                        : AppColors.textPrimary,
                  ),
                ),
              ),
              const Text(
                '提醒',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
              SizedBox(
                height: 30,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: Switch(
                    value: _task.isReminderOn,
                    onChanged: _toggleReminder,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_task.resourceUrl.isNotEmpty) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _openResource,
            icon: const Icon(Icons.open_in_new_rounded, size: 14),
            label: const Text(
              '查看学习资料',
              style: TextStyle(fontSize: 11.5),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accent,
              side: const BorderSide(color: AppColors.divider),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                size: 16,
                color: AppColors.accent,
              ),
              const SizedBox(width: 8),
              const Text(
                '任务奖励',
                style: TextStyle(
                  fontSize: 10.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                _task.reward,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _buildCompleteButton(widget.completed),
      ],
    );
  }

  Widget _buildEditContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('任务标题'),
        const SizedBox(height: 6),
        _editField(_titleController, hint: '输入任务标题', maxLines: 1),
        const SizedBox(height: 12),
        _fieldLabel('详细说明'),
        const SizedBox(height: 6),
        _editField(_descriptionController, hint: '具体怎么做', maxLines: 3),
        const SizedBox(height: 12),
        _fieldLabel('推荐时间'),
        const SizedBox(height: 6),
        _editField(_timeController, hint: '07:30 - 08:30', maxLines: 1),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _cancelEditing,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: const BorderSide(color: AppColors.divider),
                  minimumSize: const Size(0, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('取消', style: TextStyle(fontSize: 13)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: _saveEditing,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  minimumSize: const Size(0, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '保存修改',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 10.5,
        letterSpacing: 0.4,
        color: AppColors.textSecondary,
      ),
    );
  }

  Widget _editField(
    TextEditingController controller, {
    required String hint,
    required int maxLines,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      textInputAction:
          maxLines == 1 ? TextInputAction.next : TextInputAction.newline,
      style: const TextStyle(
        fontSize: 12.5,
        height: 1.4,
        color: AppColors.textPrimary,
      ),
      cursorColor: AppColors.accent,
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        hintStyle: const TextStyle(
          fontSize: 12,
          color: AppColors.textTertiary,
        ),
        filled: true,
        fillColor: AppColors.surfaceMuted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.accent,
            width: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildCompleteButton(bool completed) {
    return GestureDetector(
      onTap: completed ? null : _handleComplete,
      onTapDown: completed ? null : (_) => setState(() => _pressed = true),
      onTapUp: completed ? null : (_) => setState(() => _pressed = false),
      onTapCancel: completed ? null : () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 120),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: completed ? AppColors.surfaceMuted : AppColors.accent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (completed) ...[
                const Icon(
                  Icons.check_rounded,
                  size: 17,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                completed ? '已完成' : '完成任务',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                  color: completed ? AppColors.textSecondary : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
