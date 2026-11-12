import 'package:flutter/material.dart';
import 'package:universal_document_viewer/spreadsheet.dart';

import '../../../../core/presentation/theme/theme_extensions.dart';
import '../../../../core/presentation/widgets/reader/go_to_cell_dialog.dart';

/// Excel's name box and formula bar, read-only (CR-EXCEL-READER-AUDIT S5):
/// the active cell's address, an `fx` mark when it holds a formula, and
/// its formula (`=SUM(A1:A3)`) or its full value, which a narrow cell cuts
/// short. A long value shows on one line and expands to a few scrolling
/// lines.
///
/// [alwaysShown] keeps the bar on screen with nothing selected (tablet and
/// desktop); otherwise (phones) it appears only while a cell is selected.
/// The selection's size and totals are the grid's own status bar.
class SheetFormulaBar extends StatefulWidget {
  const SheetFormulaBar(
      {super.key, required this.sheet, required this.alwaysShown});

  final SpreadsheetController sheet;
  final bool alwaysShown;

  @override
  State<SheetFormulaBar> createState() => _SheetFormulaBarState();
}

class _SheetFormulaBarState extends State<SheetFormulaBar> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final sheet = widget.sheet;
    return ListenableBuilder(
      listenable: Listenable.merge([sheet, sheet.selection]),
      builder: (context, _) {
        final selection = sheet.selection.value;
        if (selection == null && !widget.alwaysShown)
          return const SizedBox.shrink();
        final rows = sheet.currentRows;
        final cell = selection == null
            ? null
            : _cellAt(rows, selection.activeRow, selection.activeColumn);
        final value = cell?.value;
        final formula = switch (value) {
          FormulaValue(:final formula) => '=$formula',
          _ => null,
        };
        final text = formula ?? cell?.text ?? '';
        final name = selection == null
            ? ''
            : '${columnLabel(selection.activeColumn)}${selection.activeRow + 1}';
        final canExpand = text.contains('\n') || text.length > 60;
        final muted = context.onSurfaceVariant;

        return Semantics(
          container: true,
          label: selection == null
              ? 'No cell selected'
              : '$name${formula != null ? ', formula' : ''}, ${text.isEmpty ? 'empty' : text}',
          excludeSemantics: true,
          child: Container(
            margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            decoration: BoxDecoration(
              color: context.surfaceContainerLowest,
              border: Border.all(color: context.outlineVariant),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name box: the address; tapping it goes to a cell (Excel's name box drop-down).
                InkWell(
                  key: const Key('formula-bar-goto'),
                  borderRadius:
                      const BorderRadius.horizontal(left: Radius.circular(10)),
                  onTap: () => showGoToCellDialog(context, sheet),
                  child: Tooltip(
                    message: 'Go to cell',
                    child: Container(
                      key: const Key('formula-bar-name'),
                      constraints:
                          const BoxConstraints(minWidth: 84, minHeight: 40),
                      padding: const EdgeInsets.only(left: 12, right: 4),
                      alignment: Alignment.centerLeft,
                      decoration: BoxDecoration(
                          border: Border(
                              right:
                                  BorderSide(color: context.outlineVariant))),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(name,
                              style: context.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600)),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_drop_down_rounded,
                              size: 20, color: muted),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 36,
                  height: 40,
                  child: Center(
                    child: Text(
                      'fx',
                      style: context.bodyMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: formula != null
                            ? context.primary
                            : muted.withValues(alpha: 0.5),
                        fontWeight: formula != null
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                        minHeight: 40, maxHeight: _expanded ? 120 : 40),
                    child: selection == null
                        // Nothing selected (tablet and desktop): say what to do.
                        ? Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Select a cell',
                              key: const Key('formula-bar-hint'),
                              style: context.bodyMedium?.copyWith(
                                  color: muted.withValues(alpha: 0.7)),
                            ),
                          )
                        : _expanded
                            ? SingleChildScrollView(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                child: SelectableText(text,
                                    key: const Key('formula-bar-value'),
                                    style: context.bodyMedium),
                              )
                            : Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  text.replaceAll('\n', ' '),
                                  key: const Key('formula-bar-value'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.bodyMedium,
                                ),
                              ),
                  ),
                ),
                if (canExpand)
                  IconButton(
                    tooltip: _expanded ? 'Collapse' : 'Show all',
                    icon: Icon(_expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded),
                    color: muted,
                    onPressed: () => setState(() => _expanded = !_expanded),
                  )
                else
                  const SizedBox(width: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  static SheetCell? _cellAt(List<List<SheetCell?>> rows, int row, int column) {
    if (row < 0 || row >= rows.length) return null;
    final cells = rows[row];
    return column < 0 || column >= cells.length ? null : cells[column];
  }
}
