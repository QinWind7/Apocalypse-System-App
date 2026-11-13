import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../models/system_task.dart';
import '../services/ai_service.dart';
import '../services/host_state_store.dart';
import '../services/notification_service.dart';
import '../theme.dart';
import '../widgets/app_background.dart';
import '../widgets/goal_template_sheet.dart';
import '../widgets/task_detail_sheet.dart';
import '../widgets/task_tile.dart';
import '../widgets/typewriter_text.dart';
import '../widgets/wake_time_sheet.dart';

/// 系统主界面：浅色面板 + 打字机提示 + 网格任务布局。
class SystemHomeScreen extends StatefulWidget {
  const SystemHomeScreen({super.key});

  @override
  State<SystemHomeScreen> createState() => _SystemHomeScreenState();
}

class _SystemHomeScreenState extends State<SystemHomeScreen> {
  /// 已完成任务按编号记录。
  final Set<String> _completed = <String>{};
  final AiService _aiService = const AiService();
  final HostStateStore _stateStore = const HostStateStore();
  final TextEditingController _goalController = TextEditingController();
  final FocusNode _goalFocusNode = FocusNode();

  /// 按天缓存已生成的任务。
  final Map<int, List<SystemTask>> _dayPlansCache = {};

  int _level = 1;
  int _exp = 0;
  int _combo = 0;
  String _comboDate = '';
  int _currentDay = 1;
  String _activeGoal = '';
  String _savedGoal = '';
  bool _isLoadingDay = false;
  int _requestId = 0;
  TimeOfDay _wakeTime = const TimeOfDay(hour: 8, minute: 0);
  bool _typingDone = false;
  bool _sheetOpen = false;
  bool _levelUpVisible = false;
  Timer? _levelUpTimer;

  List<SystemTask> get _visibleTasks => _dayPlansCache[_currentDay] ?? const [];

  int get _doneCount =>
      _visibleTasks.where((task) => _completed.contains(task.code)).length;
  int get _pendingCount => _visibleTasks.length - _doneCount;
  double get _progress =>
      _visibleTasks.isEmpty ? 0 : _doneCount / _visibleTasks.length;
  int get _todayCombo => _comboDate == _todayKey() ? _combo : 0;

  static String _todayKey() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }

  @override
  void initState() {
    super.initState();
    _restoreState();
    _restoreGoal();
    _restorePlans();
    _restoreWakeTime();
  }

  Future<void> _restorePlans() async {
    final cached = await _stateStore.loadPlans();
    if (!mounted || cached == null || cached.dayTasks.isEmpty) return;

    setState(() {
      _dayPlansCache
        ..clear()
        ..addAll(cached.dayTasks);
      _currentDay = cached.currentDay;
      if (cached.goal.isNotEmpty) {
        _activeGoal = cached.goal;
        _savedGoal = cached.goal;
        if (_goalController.text.isEmpty) {
          _goalController.value = TextEditingValue(
            text: cached.goal,
            selection: TextSelection.collapsed(offset: cached.goal.length),
          );
        }
      }
    });
  }

  void _persistPlans() {
    final snapshot = <int, List<SystemTask>>{
      for (final entry in _dayPlansCache.entries)
        entry.key: List<SystemTask>.of(entry.value),
    };
    _stateStore.savePlans(
      snapshot,
      _currentDay,
      _activeGoal.isNotEmpty ? _activeGoal : _savedGoal,
    );
  }

  Future<void> _restoreGoal() async {
    final goal = await _stateStore.loadGoal();
    if (!mounted || goal.isEmpty) return;

    _savedGoal = goal;
    if (_goalController.text.isEmpty) {
      _goalController.value = TextEditingValue(
        text: goal,
        selection: TextSelection.collapsed(offset: goal.length),
      );
    }
  }

  Future<void> _restoreWakeTime() async {
    final time = await NotificationService.instance.loadWakeTime();
    if (!mounted) return;
    setState(() => _wakeTime = time);
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _openSettings() async {
    setState(() => _sheetOpen = true);
    final selected = await showModalBottomSheet<TimeOfDay>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.15),
      builder: (sheetContext) {
        return WakeTimeSheet(initialTime: _wakeTime);
      },
    );
    if (!mounted) return;
    setState(() => _sheetOpen = false);
    if (selected == null) return;

    setState(() => _wakeTime = selected);

    var granted = false;
    try {
      granted = await NotificationService.instance.setWakeTime(selected);
    } catch (_) {
      granted = false;
    }
    if (!mounted) return;

    final label = _formatTime(selected);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          granted ? '已设置每日 $label 系统唤醒提醒' : '已保存 $label，但通知权限未开启，可能无法收到提醒',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _restoreState() async {
    final state = await _stateStore.load();
    if (!mounted) return;

    setState(() {
      _level = state.level < 1 ? 1 : state.level;
      _exp = state.exp.clamp(0, 99).toInt();
      _completed
        ..clear()
        ..addAll(state.completed);
      _combo = state.combo;
      _comboDate = state.comboDate;
    });
  }

  void _saveState() {
    _stateStore.save(
      HostState(
        level: _level,
        exp: _exp,
        completed: Set<String>.of(_completed),
        combo: _combo,
        comboDate: _comboDate,
      ),
    );
  }

  @override
  void dispose() {
    _levelUpTimer?.cancel();
    _goalController.dispose();
    _goalFocusNode.dispose();
    super.dispose();
  }

  Future<void> _showTemplates() async {
    FocusScope.of(context).unfocus();
    setState(() => _sheetOpen = true);
    final goal = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.15),
      builder: (sheetContext) => const GoalTemplateSheet(),
    );
    if (!mounted) return;
    setState(() => _sheetOpen = false);
    if (goal == null) return;

    setState(() {
      _goalController.value = TextEditingValue(
        text: goal,
        selection: TextSelection.collapsed(offset: goal.length),
      );
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _goalFocusNode.requestFocus();
    });
  }

  Future<void> _generateTasks() async {
    FocusScope.of(context).unfocus();

    final goal = _goalController.text.trim();
    if (goal.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先输入你的长期目标'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final previousGoal = _activeGoal.isNotEmpty ? _activeGoal : _savedGoal;
    final isNewPlan = previousGoal.isNotEmpty && previousGoal != goal;

    // 目标未变且已有缓存：不重复请求，也不重置任何进度。
    if (!isNewPlan && _dayPlansCache.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('当前目标已生成因果线，长按 Day 标签可重新生成该天任务'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (isNewPlan) {
      final confirmed = await _confirmNewPlan();
      if (!confirmed || !mounted) return;
    }

    final requestId = ++_requestId;
    setState(() {
      _activeGoal = goal;
      _savedGoal = goal;
      if (_dayPlansCache.isEmpty) _currentDay = 1;
      if (isNewPlan) {
        _currentDay = 1;
        _dayPlansCache.clear();
        _completed.clear();
        _level = 1;
        _exp = 0;
        _combo = 0;
        _comboDate = '';
        _levelUpTimer?.cancel();
        _levelUpVisible = false;
      }
      _isLoadingDay = true;
    });
    if (isNewPlan) {
      _stateStore.clearPlans();
      _saveState();
    }
    _stateStore.saveGoal(goal);

    List<SystemTask> tasks;
    try {
      tasks = await _aiService.generateSingleDayPlan(goal, 1);
    } catch (_) {
      if (!mounted || requestId != _requestId) return;
      setState(() => _isLoadingDay = false);
      return;
    }
    if (!mounted || requestId != _requestId) return;

    setState(() {
      _dayPlansCache[1] = tasks;
      _isLoadingDay = false;
    });
    _persistPlans();
  }

  Future<bool> _confirmNewPlan() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('目标已修改'),
        content: const Text('将开启新档，清空当前任务缓存、等级、经验、连击与完成记录。是否继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('确认开新档'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  void _selectDay(int day) {
    if (day == _currentDay) return;
    setState(() => _currentDay = day);
    _persistPlans();

    if (!_dayPlansCache.containsKey(day)) {
      _loadDay(day);
    }
  }

  /// 重新生成某一天的任务：只清除该天的缓存与完成记录，不动其余进度。
  Future<void> _refreshDay(int day) async {
    if (_isLoadingDay || _activeGoal.isEmpty) return;

    final oldTasks = _dayPlansCache[day];
    final requestId = ++_requestId;
    setState(() {
      _currentDay = day;
      if (oldTasks != null) {
        final oldCodes = oldTasks.map((task) => task.code).toSet();
        _completed.removeAll(oldCodes);
        _dayPlansCache.remove(day);
      }
      _isLoadingDay = true;
    });
    _saveState();
    _persistPlans();

    List<SystemTask> tasks;
    try {
      tasks = await _aiService.generateSingleDayPlan(_activeGoal, day);
    } catch (_) {
      if (!mounted || requestId != _requestId) return;
      setState(() => _isLoadingDay = false);
      return;
    }
    if (!mounted || requestId != _requestId) return;

    setState(() {
      _dayPlansCache[day] = tasks;
      _isLoadingDay = false;
    });
    _persistPlans();
  }

  /// 按需生成某一天的任务并写入缓存。
  Future<void> _loadDay(int day) async {
    if (_isLoadingDay || _dayPlansCache.containsKey(day)) return;
    if (_activeGoal.isEmpty) return;

    final requestId = ++_requestId;
    setState(() => _isLoadingDay = true);

    List<SystemTask> tasks;
    try {
      tasks = await _aiService.generateSingleDayPlan(_activeGoal, day);
    } catch (_) {
      if (!mounted || requestId != _requestId) return;
      setState(() => _isLoadingDay = false);
      return;
    }
    if (!mounted || requestId != _requestId) return;

    setState(() {
      _dayPlansCache[day] = tasks;
      _isLoadingDay = false;
    });
    _persistPlans();
  }

  /// 当前天没有缓存且未在加载时，下一帧自动发起请求。
  void _scheduleAutoLoadIfNeeded() {
    if (_isLoadingDay || _visibleTasks.isNotEmpty) return;
    if (_activeGoal.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_isLoadingDay || _visibleTasks.isNotEmpty) return;
      _loadDay(_currentDay);
    });
  }

  void _handleComplete(String code) {
    if (_completed.contains(code)) return;

    final today = _todayKey();
    final sameDay = _comboDate == today;

    var level = _level;
    var exp = _exp + 10;
    var leveledUp = false;
    while (exp >= 100) {
      exp -= 100;
      level += 1;
      leveledUp = true;
    }

    setState(() {
      _completed.add(code);
      _level = level;
      _exp = exp;
      _combo = sameDay ? _combo + 1 : 1;
      _comboDate = today;
    });

    _saveState();

    if (leveledUp) _showLevelUp();
  }

  void _showLevelUp() {
    _levelUpTimer?.cancel();
    setState(() => _levelUpVisible = true);
    _levelUpTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _levelUpVisible = false);
    });
  }

  Future<void> _openTaskDetail(SystemTask task) async {
    setState(() => _sheetOpen = true);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.15),
      builder: (sheetContext) {
        return TaskDetailSheet(
          task: task,
          completed: _completed.contains(task.code),
          onComplete: () {
            Navigator.of(sheetContext).pop();
            _handleComplete(task.code);
          },
          onUpdated: (updated) {
            final dayTasks = _dayPlansCache[updated.day];
            if (dayTasks == null) return;
            final index = dayTasks.indexWhere(
              (item) => item.code == updated.code,
            );
            if (index < 0) return;
            setState(() => dayTasks[index] = updated);
            _persistPlans();
          },
        );
      },
    );
    if (mounted) setState(() => _sheetOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    // 键盘弹起时收起次要信息，避免底栏被顶起后布局溢出。
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          AppBackground(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                child: Column(
                  children: [
                    Expanded(
                      child: _SystemPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildStatusBar(),
                            const SizedBox(height: 12),
                            _buildHostStatus(),
                            Visibility(
                              visible: !keyboardVisible,
                              maintainState: true,
                              maintainAnimation: true,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 12),
                                  _buildSystemMessage(),
                                  const SizedBox(height: 14),
                                ],
                              ),
                            ),
                            _buildGoalInput(),
                            const SizedBox(height: 16),
                            _buildTaskHeader(),
                            const SizedBox(height: 8),
                            _buildDaySwitcher(),
                            const SizedBox(height: 8),
                            Expanded(child: _buildTaskList()),
                            if (!keyboardVisible) ...[
                              const SizedBox(height: 12),
                              SafeArea(top: false, child: _buildFooter()),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (!keyboardVisible) ...[
                      const SizedBox(height: 10),
                      const Text(
                        'SYSTEM VERSION 1.0.4 // ALL RIGHTS RESERVED',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 8,
                          letterSpacing: 1.1,
                          fontFamily: 'monospace',
                          color: Color(0xFFC6CCD8),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          // 弹窗打开时，主界面轻微变暗并柔化，突出弹窗层级。
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOut,
                opacity: _sheetOpen ? 1 : 0,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                  child: const ColoredBox(color: Color(0x0A000000)),
                ),
              ),
            ),
          ),
          // 升级提示：全屏微光，不拦截操作。
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOut,
                opacity: _levelUpVisible ? 1 : 0,
                child: _LevelUpFlash(level: _level),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.accent,
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          '天命系统',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 6),
        const Text(
          'SYSTEM',
          style: TextStyle(
            fontSize: 9,
            letterSpacing: 1.4,
            color: AppColors.textTertiary,
          ),
        ),
        const Spacer(),
        const _PulseDot(),
        const SizedBox(width: 6),
        const Text(
          'ONLINE',
          style: TextStyle(
            fontSize: 9,
            letterSpacing: 1.2,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _openSettings,
          child: const Padding(
            padding: EdgeInsets.all(6),
            child: Icon(
              Icons.settings_outlined,
              size: 16,
              color: AppColors.textTertiary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHostStatus() {
    final combo = _todayCombo;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.accentSoft,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'LV.$_level',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: AppColors.accent,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: SizedBox(
              height: 3,
              child: Stack(
                children: [
                  const Positioned.fill(
                    child: ColoredBox(color: AppColors.divider),
                  ),
                  Positioned.fill(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: _exp / 100),
                      duration: const Duration(milliseconds: 380),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) {
                        return FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: value,
                          child: const ColoredBox(color: AppColors.accent),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'EXP: $_exp/100',
          style: const TextStyle(
            fontSize: 9.5,
            fontFamily: 'monospace',
            letterSpacing: 0.3,
            color: AppColors.techLabel,
          ),
        ),
        if (combo >= 2) ...[
          const SizedBox(width: 10),
          Text(
            '$combo 连击',
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: AppColors.accent,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSystemMessage() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 14, 16, 14),
            color: AppColors.accentSoft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TypewriterText(
                  text: '【叮！系统检测到宿主，正在加载今日任务...】',
                  charDelay: const Duration(milliseconds: 46),
                  style: const TextStyle(
                    fontSize: 14.5,
                    height: 1.55,
                    letterSpacing: 0.4,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  onCompleted: () {
                    if (mounted) setState(() => _typingDone = true);
                  },
                ),
                const SizedBox(height: 7),
                AnimatedOpacity(
                  opacity: _typingDone ? 1 : 0,
                  duration: const Duration(milliseconds: 420),
                  child: Text(
                    '同步完成 · 当前天共 ${_visibleTasks.length} 项任务 · 请宿主尽快执行',
                    style: const TextStyle(
                      fontSize: 11,
                      letterSpacing: 0.2,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 左侧极细竖向渐变条：深蓝 → 透明。
          Positioned(
            left: 0,
            top: 12,
            bottom: 12,
            child: Container(
              width: 2,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(1),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.accent,
                    AppColors.accent.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalInput() {
    return Row(
      children: [
        SizedBox(
          height: 46,
          child: OutlinedButton(
            onPressed: _isLoadingDay ? null : _showTemplates,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accent,
              side: const BorderSide(color: AppColors.divider),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              '模板',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: _goalController,
            focusNode: _goalFocusNode,
            enabled: !_isLoadingDay,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _generateTasks(),
            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
            cursorColor: AppColors.accent,
            decoration: InputDecoration(
              isDense: true,
              hintText: '输入你的长期目标',
              hintStyle: const TextStyle(
                fontSize: 12,
                color: AppColors.textTertiary,
              ),
              filled: true,
              fillColor: AppColors.surfaceMuted,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 13,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: AppColors.accent,
                  width: 1.2,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          height: 46,
          child: FilledButton(
            onPressed: _isLoadingDay
                ? null
                : () {
                    FocusScope.of(context).unfocus();
                    _generateTasks();
                  },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              disabledBackgroundColor: AppColors.textTertiary,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _isLoadingDay
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    '生成',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildTaskHeader() {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'DAY $_currentDay',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 8),
        const Expanded(
          child: Text(
            'DAILY QUESTS',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 8.5,
              letterSpacing: 1.2,
              color: AppColors.textTertiary,
            ),
          ),
        ),
        Text(
          '待处理 $_pendingCount',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.accent,
          ),
        ),
      ],
    );
  }

  Widget _buildDaySwitcher() {
    return SizedBox(
      height: 28,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: 7,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final day = index + 1;
          final selected = day == _currentDay;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _selectDay(day),
            onLongPress: () => _refreshDay(day),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: selected ? AppColors.accent : AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: selected ? AppColors.accent : AppColors.divider,
                ),
              ),
              child: Text(
                'Day $day',
                style: TextStyle(
                  fontSize: 10,
                  fontFamily: 'monospace',
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTaskList() {
    if (!_typingDone) return const SizedBox.expand();

    final tasks = _visibleTasks;
    if (tasks.isEmpty) {
      if (_isLoadingDay) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '系统正在计算第 $_currentDay 天的因果线...',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        );
      }

      if (_activeGoal.isEmpty) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              '【系统提示】请先输入目标并点击生成。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                height: 1.6,
                color: AppColors.textTertiary,
              ),
            ),
          ),
        );
      }

      _scheduleAutoLoadIfNeeded();
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            '【系统提示】Day $_currentDay 尚未解锁，正在计算因果线...',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              height: 1.6,
              color: AppColors.textTertiary,
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // 宽屏 3 列，手机 2 列；任务较少时整行居中，不强行撑满。
        final columns = constraints.maxWidth >= 520 ? 3 : 2;
        const spacing = 12.0;
        final tileSize =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (var index = 0; index < tasks.length; index++)
                SizedBox(
                  width: tileSize,
                  height: tileSize,
                  child: TaskTile(
                    key: ValueKey(tasks[index].code),
                    task: tasks[index],
                    completed: _completed.contains(tasks[index].code),
                    appearDelay: Duration(milliseconds: 90 * index),
                    onTap: () => _openTaskDetail(tasks[index]),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Row(
          children: [
            const Text(
              '同步进度',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 0.3,
                color: AppColors.textSecondary,
              ),
            ),
            const Spacer(),
            Text(
              '$_doneCount / ${_visibleTasks.length}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.accent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 10,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: _progress),
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return CustomPaint(
                painter: _HatchProgressPainter(progress: value),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 白色圆角面板，承载整个系统界面。
class _SystemPanel extends StatelessWidget {
  const _SystemPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.divider),
        boxShadow: AppShadows.panel,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(27),
        child: Stack(
          children: [
            // 面板是不透明白底，纹理需绘制在白底之上、内容之下才可见。
            const Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(child: SystemTechLayer()),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

/// 右上角呼吸的在线指示点（浅色版，无发光）。
class _PulseDot extends StatefulWidget {
  const _PulseDot();

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_controller.value);
        return Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.success.withValues(alpha: 0.3 + 0.7 * t),
          ),
        );
      },
    );
  }
}

/// 斜纹进度条：轨道为浅色小斜线，已完成部分为深蓝色斜线。
class _HatchProgressPainter extends CustomPainter {
  const _HatchProgressPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(rect, const Radius.circular(3)));

    canvas.drawRect(rect, Paint()..color = const Color(0xFFF2F4F9));

    const spacing = 5.0;
    final trackPaint = Paint()
      ..color = const Color(0xFFDDE3EF)
      ..strokeWidth = 1;
    final fillPaint = Paint()
      ..color = AppColors.accent
      ..strokeWidth = 1.4;

    void drawHatches(Paint paint) {
      for (double x = -size.height; x <= size.width + spacing; x += spacing) {
        canvas.drawLine(
          Offset(x, size.height),
          Offset(x + size.height, 0),
          paint,
        );
      }
    }

    drawHatches(trackPaint);

    if (progress > 0) {
      canvas.save();
      canvas.clipRect(
        Rect.fromLTWH(0, 0, size.width * progress.clamp(0.0, 1.0), size.height),
      );
      canvas.drawRect(rect, Paint()..color = const Color(0xFFEDEFFA));
      drawHatches(fillPaint);
      canvas.restore();
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HatchProgressPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// 升级提示：全屏微光 + 中央系统提示卡。
class _LevelUpFlash extends StatelessWidget {
  const _LevelUpFlash({required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          colors: [
            AppColors.accent.withValues(alpha: 0.10),
            AppColors.accent.withValues(alpha: 0.03),
            Colors.transparent,
          ],
          stops: const [0.0, 0.45, 1.0],
        ),
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.15)),
            boxShadow: AppShadows.card,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '【系统提示】',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.2,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '宿主等级提升！',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'LEVEL UP · LV.$level',
                style: const TextStyle(
                  fontSize: 10,
                  fontFamily: 'monospace',
                  letterSpacing: 1,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
