library;

import 'package:dynamic_color/dynamic_color.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/clash_config.dart';
import 'package:fl_clash/models/state.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/card.dart';
import 'package:fl_clash/widgets/dialog.dart';
import 'package:fl_clash/widgets/input.dart';
import 'package:fl_clash/widgets/list.dart';
import 'package:fl_clash/widgets/text.dart';
import 'package:flutter/material.dart';

final ruleItemHeight = globalState.measure.bodyMediumHeight * 2 + 14;

class RuleItem extends StatelessWidget {
  final bool isSelected;
  final bool isEditing;
  final Rule rule;
  final void Function() onSelected;
  final void Function(Rule rule) onEdit;
  final bool Function(Rule rule)? checkInvalidHandler;

  const RuleItem({
    super.key,
    required this.isSelected,
    required this.rule,
    required this.onSelected,
    required this.onEdit,
    this.checkInvalidHandler,
    this.isEditing = false,
  });

  VM2<bool, Color> _checkInvalid(BuildContext context) {
    if (rule.ruleAction != RuleAction.SUB_RULE) {
      final ruleTarget = rule.ruleTarget ?? '';
      if (ruleTarget.toUpperCase() == 'DIRECT') {
        return VM2(
          false,
          Colors.green.harmonizeWith(context.colorScheme.primary),
        );
      } else if (ruleTarget.toUpperCase() == 'REJECT') {
        return VM2(false, context.colorScheme.error);
      }
    }
    bool invalid = true;
    if (checkInvalidHandler != null) {
      invalid = checkInvalidHandler!(rule);
    }
    return VM2(
      invalid,
      invalid
          ? Colors.grey.harmonizeWith(context.colorScheme.primary)
          : context.colorScheme.onSecondaryContainer,
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm2 = _checkInvalid(context);
    final invalid = vm2.a;
    return SelectedDecorationListItem(
      isSelected: isSelected,
      isEditing: isEditing,
      horizontalTitleGap: 0,
      invalid: invalid,
      onSelected: () {
        onSelected();
      },
      title: Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rule.ruleAction.name,
                  style: context.textTheme.bodyLarge?.toJetBrainsMono,
                ),
                Flexible(
                  child: TooltipText(
                    text: Text(
                      rule.realContent ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.bodySmall?.toJetBrainsMono
                          .copyWith(
                            color:
                                context.colorScheme.onSurfaceVariant.opacity80,
                          ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (rule.realTarget != null)
            Text(
              rule.realTarget!,
              style: context.textTheme.bodyMedium?.toJetBrainsMono.copyWith(
                color: vm2.b,
              ),
            ),
        ],
      ),
      onPressed: () {
        onEdit(rule);
      },
    );
  }
}

class RuleStatusItem extends StatelessWidget {
  final bool status;
  final Rule rule;
  final void Function(bool) onChange;

  const RuleStatusItem({
    super.key,
    required this.status,
    required this.rule,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return DecorationListItem(
      title: TooltipText(
        text: Text(
          rule.rawValue,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: context.textTheme.bodyMedium?.toJetBrainsMono,
        ),
      ),
      trailing: Switch(value: status, onChanged: onChange),
      onPressed: () {
        onChange(!status);
      },
    );
  }
}

class AddOrEditRuleDialog extends StatefulWidget {
  final Rule? rule;

  const AddOrEditRuleDialog({super.key, this.rule});

  @override
  State<AddOrEditRuleDialog> createState() => _AddOrEditRuleDialogState();
}

class _AddOrEditRuleDialogState extends State<AddOrEditRuleDialog> {
  late RuleAction _ruleAction;
  final _ruleTargetController = TextEditingController();
  final _contentController = TextEditingController();
  bool _noResolve = false;
  bool _src = false;
  List<DropdownMenuEntry> _targetItems = [];
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    _initState();
    super.initState();
  }

  void _initState() {
    _targetItems = [
      ...RuleTarget.values.map(
        (item) => DropdownMenuEntry(value: item.name, label: item.name),
      ),
      DropdownMenuEntry(value: 'MATCH', label: 'MATCH'),
    ];
    final rule = widget.rule;
    if (rule != null) {
      _ruleAction = rule.ruleAction;
      _contentController.text = rule.content ?? '';
      _ruleTargetController.text = rule.ruleTarget ?? '';
      _noResolve = rule.noResolve;
      _src = rule.src;
      return;
    }
    _ruleAction = RuleAction.addedRuleActions.first;
    if (_targetItems.isNotEmpty) {
      _ruleTargetController.text = _targetItems.first.value;
    }
  }

  @override
  void didUpdateWidget(AddOrEditRuleDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rule != widget.rule) {
      _initState();
    }
  }

  void _handleSubmit() {
    final res = _formKey.currentState?.validate();
    if (res == false) {
      return;
    }
    final rule = Rule(
      id: widget.rule?.id ?? -1,
      ruleAction: _ruleAction,
      content: _contentController.text,
      ruleTarget: _ruleTargetController.text,
      noResolve: _noResolve,
      src: _src,
    );
    Navigator.of(context).pop(rule);
  }

  @override
  Widget build(BuildContext context) {
    return CommonDialog(
      title: widget.rule != null
          ? appLocalizations.editRule
          : appLocalizations.addRule,
      actions: [
        TextButton(
          onPressed: _handleSubmit,
          child: Text(appLocalizations.confirm),
        ),
      ],
      child: DropdownMenuTheme(
        data: DropdownMenuThemeData(
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(),
            labelStyle: context.textTheme.bodyLarge?.copyWith(
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        child: Form(
          key: _formKey,
          child: LayoutBuilder(
            builder: (_, constraints) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FilledButton.tonal(
                    onPressed: () async {
                      _ruleAction =
                          await globalState.showCommonDialog<RuleAction>(
                            filter: false,
                            child: OptionsDialog<RuleAction>(
                              title: appLocalizations.ruleName,
                              options: RuleAction.addedRuleActions,
                              textBuilder: (item) => item.value,
                              value: _ruleAction,
                            ),
                          ) ??
                          _ruleAction;
                      setState(() {});
                    },
                    child: Text(_ruleAction.value),
                  ),
                  SizedBox(height: 24),
                  TextFormField(
                    keyboardType: TextInputType.text,
                    onFieldSubmitted: (_) {
                      _handleSubmit();
                    },
                    controller: _contentController,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: appLocalizations.content,
                    ),
                    validator: (_) {
                      if (_contentController.text.isEmpty) {
                        return appLocalizations.emptyTip(
                          appLocalizations.content,
                        );
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 24),
                  FormField<String>(
                    validator: (_) {
                      if (_ruleTargetController.text.isEmpty) {
                        return appLocalizations.emptyTip(
                          appLocalizations.ruleTarget,
                        );
                      }
                      return null;
                    },
                    builder: (filed) {
                      return DropdownMenu(
                        controller: _ruleTargetController,
                        label: Text(appLocalizations.ruleTarget),
                        width: 200,
                        menuHeight: 250,
                        enableFilter: false,
                        enableSearch: false,
                        dropdownMenuEntries: _targetItems,
                        errorText: filed.errorText,
                      );
                    },
                  ),
                  if (_ruleAction.hasParams) ...[
                    SizedBox(height: 20),
                    Wrap(
                      spacing: 8,
                      children: [
                        CommonCard(
                          radius: 8,
                          isSelected: _src,
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                            child: Text(
                              appLocalizations.sourceIp,
                              style: context.textTheme.bodyMedium,
                            ),
                          ),
                          onPressed: () {
                            setState(() {
                              _src = !_src;
                            });
                          },
                        ),
                        CommonCard(
                          radius: 8,
                          isSelected: _noResolve,
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                            child: Text(
                              appLocalizations.noResolve,
                              style: context.textTheme.bodyMedium,
                            ),
                          ),
                          onPressed: () {
                            setState(() {
                              _noResolve = !_noResolve;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                  SizedBox(height: 20),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
