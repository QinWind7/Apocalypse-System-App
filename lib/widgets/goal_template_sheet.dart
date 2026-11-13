import 'package:flutter/material.dart';

import '../theme.dart';

/// 系统预设目标指令。
class GoalTemplate {
  const GoalTemplate({
    required this.id,
    required this.title,
    required this.description,
    required this.fullPrompt,
  });

  final String id;
  final String title;
  final String description;
  final String fullPrompt;
}

/// 目标模板选择面板：点击后返回完整目标文本。
class GoalTemplateSheet extends StatelessWidget {
  const GoalTemplateSheet({super.key});

  static const List<GoalTemplate> templates = [
    GoalTemplate(
      id: 'SYS-T-01',
      title: '考研突围',
      description: '3个月完成初试全科复习，每日高效备考。',
      fullPrompt: '考研冲刺：3个月内完成初试全科复习，每天保持6小时高效学习',
    ),
    GoalTemplate(
      id: 'SYS-T-02',
      title: '基因重构',
      description: '体脂下降5%，强化力量与有氧训练。',
      fullPrompt: '减脂增肌：3个月内体脂率下降5%，每周4次力量训练并控制饮食',
    ),
    GoalTemplate(
      id: 'SYS-T-03',
      title: '知识汲取',
      description: '每周精读一本书并输出结构化笔记。',
      fullPrompt: '高效阅读：2个月内每周读完一本书，并输出一篇结构化读书笔记',
    ),
    GoalTemplate(
      id: 'SYS-T-04',
      title: '编制夺取',
      description: '行测申论双线推进，全真模拟冲刺。',
      fullPrompt: '考公上岸：3个月内完成行测与申论的系统复习，每周进行一次全真模拟',
    ),
    GoalTemplate(
      id: 'SYS-T-05',
      title: '外语破解',
      description: '词汇量突破8000，攻克长难句。',
      fullPrompt: '英语逆袭：2个月内词汇量突破8000，每天精读一篇外刊',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Container(
          margin: const EdgeInsets.all(14),
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(26),
            boxShadow: AppShadows.panel,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                '【系统预设指令】',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '选择协议，快速注入目标',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              for (final template in templates)
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => Navigator.of(context).pop(template.fullPrompt),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 62,
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: Text(
                            template.id,
                            style: const TextStyle(
                              fontSize: 8.5,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                template.title,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                template.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  height: 1.5,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: AppColors.textTertiary,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
