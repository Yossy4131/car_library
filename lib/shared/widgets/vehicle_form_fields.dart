import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 共通: オートコンプリートのドロップダウンリスト
// ─────────────────────────────────────────────────────────────────────────────

Widget _buildOptionsView(
  BuildContext ctx,
  AutocompleteOnSelected<String> onSelected,
  Iterable<String> options,
) {
  return Align(
    alignment: Alignment.topLeft,
    child: Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 200),
        child: ListView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          itemCount: options.length,
          itemBuilder: (ctx, index) {
            final option = options.elementAt(index);
            return ListTile(
              dense: true,
              title: Text(option),
              onTap: () => onSelected(option),
            );
          },
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// NhtsaMakerField — メーカーオートコンプリートフィールド
// ─────────────────────────────────────────────────────────────────────────────

class NhtsaMakerField extends StatelessWidget {
  final AsyncValue<List<String>> nhtsaMakersAsync;
  final ValueNotifier<String?> selectedMaker;
  final ValueNotifier<String?> selectedModel;
  final ValueNotifier<String> makerFreeText;
  final ValueNotifier<String> modelFreeText;

  /// false のとき全フィールドを disabled にする（投稿中など）
  final bool enabled;

  /// 初期表示文字列（省略時は makerFreeText.value を使用）
  final String? initialValue;

  const NhtsaMakerField({
    super.key,
    required this.nhtsaMakersAsync,
    required this.selectedMaker,
    required this.selectedModel,
    required this.makerFreeText,
    required this.modelFreeText,
    this.enabled = true,
    this.initialValue,
  });

  @override
  Widget build(BuildContext context) {
    return nhtsaMakersAsync.when(
      loading: () => const TextField(
        decoration: InputDecoration(
          labelText: 'メーカー *',
          hintText: 'メーカー一覧を読み込み中...',
          border: OutlineInputBorder(),
          suffixIcon: Padding(
            padding: EdgeInsets.all(12.0),
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        enabled: false,
      ),
      error: (_, __) => TextField(
        decoration: const InputDecoration(
          labelText: 'メーカー *',
          hintText: '例: TOYOTA, HONDA（手動入力）',
          border: OutlineInputBorder(),
          helperText: 'APIが利用できません。直接入力してください',
        ),
        onChanged: (v) {
          makerFreeText.value = v;
          selectedMaker.value = null;
          selectedModel.value = null;
          modelFreeText.value = '';
        },
        enabled: enabled,
      ),
      data: (makers) => Autocomplete<String>(
        initialValue: TextEditingValue(
          text: initialValue ?? makerFreeText.value,
        ),
        optionsBuilder: (textEditingValue) {
          final query = textEditingValue.text.trim();
          if (query.isEmpty) return const Iterable<String>.empty();
          final lower = query.toLowerCase();
          return makers.where((m) => m.toLowerCase().contains(lower)).take(10);
        },
        onSelected: (value) {
          selectedMaker.value = value;
          makerFreeText.value = value;
          selectedModel.value = null;
          modelFreeText.value = '';
        },
        fieldViewBuilder: (ctx, controller, focusNode, _) => TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: const InputDecoration(
            labelText: 'メーカー *',
            hintText: 'メーカー名を入力して検索',
            border: OutlineInputBorder(),
            helperText: '例: TOYOTA, HONDA, NISSAN',
          ),
          enabled: enabled,
          onChanged: (v) {
            makerFreeText.value = v;
            if (selectedMaker.value != null && v != selectedMaker.value) {
              selectedMaker.value = null;
              selectedModel.value = null;
              modelFreeText.value = '';
            }
          },
        ),
        optionsViewBuilder: _buildOptionsView,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NhtsaModelField — 車種オートコンプリートフィールド
// ─────────────────────────────────────────────────────────────────────────────

class NhtsaModelField extends StatelessWidget {
  final AsyncValue<List<String>> nhtsaModelsAsync;
  final ValueNotifier<String?> selectedMaker;
  final ValueNotifier<String?> selectedModel;
  final ValueNotifier<String> modelFreeText;

  /// false のとき全フィールドを disabled にする
  final bool enabled;

  /// 初期表示文字列（省略時は modelFreeText.value を使用）
  final String? initialValue;

  const NhtsaModelField({
    super.key,
    required this.nhtsaModelsAsync,
    required this.selectedMaker,
    required this.selectedModel,
    required this.modelFreeText,
    this.enabled = true,
    this.initialValue,
  });

  @override
  Widget build(BuildContext context) {
    final hasMaker =
        selectedMaker.value != null && selectedMaker.value!.isNotEmpty;

    if (!hasMaker) {
      return const TextField(
        decoration: InputDecoration(
          labelText: '車種名 *',
          hintText: '先にメーカーを選択してください',
          border: OutlineInputBorder(),
        ),
        enabled: false,
      );
    }

    return nhtsaModelsAsync.when(
      loading: () => const TextField(
        decoration: InputDecoration(
          labelText: '車種名 *',
          hintText: '車種一覧を読み込み中...',
          border: OutlineInputBorder(),
          suffixIcon: Padding(
            padding: EdgeInsets.all(12.0),
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        enabled: false,
      ),
      error: (_, __) => TextField(
        decoration: const InputDecoration(
          labelText: '車種名 *',
          hintText: '例: Corolla, Civic（手動入力）',
          border: OutlineInputBorder(),
          helperText: 'APIが利用できません。直接入力してください',
        ),
        onChanged: (v) {
          modelFreeText.value = v;
          selectedModel.value = null;
        },
        enabled: enabled,
      ),
      data: (models) => Autocomplete<String>(
        key: ValueKey(selectedMaker.value), // メーカー変更でウィジェットをリセット
        initialValue: TextEditingValue(
          text: initialValue ?? modelFreeText.value,
        ),
        optionsBuilder: (textEditingValue) {
          final query = textEditingValue.text.trim();
          if (query.isEmpty) return models.take(10);
          final lower = query.toLowerCase();
          return models.where((m) => m.toLowerCase().contains(lower)).take(10);
        },
        onSelected: (value) {
          selectedModel.value = value;
          modelFreeText.value = value;
        },
        fieldViewBuilder: (ctx, controller, focusNode, _) => TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: const InputDecoration(
            labelText: '車種名 *',
            hintText: '車種名を入力して検索',
            border: OutlineInputBorder(),
          ),
          enabled: enabled,
          onChanged: (v) {
            modelFreeText.value = v;
            if (selectedModel.value != null && v != selectedModel.value) {
              selectedModel.value = null;
            }
          },
        ),
        optionsViewBuilder: _buildOptionsView,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TagInputField — ハッシュタグ入力フィールド
// ─────────────────────────────────────────────────────────────────────────────

class TagInputField extends StatelessWidget {
  final TextEditingController controller;
  final List<String> tags;
  final bool enabled;
  final void Function(String tag) onAddTag;
  final void Function(String tag) onRemoveTag;

  const TagInputField({
    super.key,
    required this.controller,
    required this.tags,
    this.enabled = true,
    required this.onAddTag,
    required this.onRemoveTag,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          enabled: enabled,
          decoration: InputDecoration(
            labelText: 'ハッシュタグ',
            hintText: '例: スポーツカー（最大10個）',
            border: const OutlineInputBorder(),
            helperText: '入力してEnterで追加。# は自動で付きます。',
            suffixIcon: IconButton(
              icon: const Icon(Icons.add),
              onPressed: enabled
                  ? () {
                      final v = controller.text.trim();
                      if (v.isNotEmpty) onAddTag(v);
                    }
                  : null,
            ),
          ),
          onSubmitted: (v) {
            if (v.trim().isNotEmpty) onAddTag(v.trim());
          },
          onChanged: (v) {
            if (v.endsWith(' ') || v.endsWith('　')) {
              final trimmed = v.trim();
              if (trimmed.isNotEmpty) onAddTag(trimmed);
            }
          },
        ),
        if (tags.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: tags
                .map(
                  (tag) => Chip(
                    label: Text('#$tag'),
                    deleteIcon: const Icon(Icons.close, size: 14),
                    onDeleted: () => onRemoveTag(tag),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }
}
