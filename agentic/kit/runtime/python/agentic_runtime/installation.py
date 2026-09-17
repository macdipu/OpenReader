"""Host instruction merging and read-only installation state inspection."""
import copy
import json
from pathlib import Path

BEGIN = '<!-- agentic-kit:start -->'
END = '<!-- agentic-kit:end -->'


def managed_text(existing, addition):
    block = BEGIN + '\n' + addition.rstrip() + '\n' + END
    if BEGIN in existing or END in existing:
        if existing.count(BEGIN) != 1 or existing.count(END) != 1 or existing.index(BEGIN) > existing.index(END):
            raise ValueError('Malformed managed instruction block; preserve and repair it before installing')
        before, rest = existing.split(BEGIN, 1)
        _, after = rest.split(END, 1)
        return before + block + after
    return existing + ('\n\n' if existing and not existing.endswith('\n\n') else '') + block + '\n'


def merge_hooks(existing, template):
    result = copy.deepcopy(existing)
    hooks = result.setdefault('hooks', {})
    if not isinstance(hooks, dict):
        raise ValueError('Existing hooks must be an object')
    for event, entries in template['hooks'].items():
        current = hooks.setdefault(event, [])
        if not isinstance(current, list):
            raise ValueError('Existing hook event must be an array: ' + event)
        for entry in entries:
            if entry not in current:
                current.append(copy.deepcopy(entry))
    return result


def unfinished_runs(root):
    db = Path(root) / 'agentic/data/runtime/state/agentic.db'
    if not db.exists():
        return []
    from .store import RuntimeStore
    return [r for r in RuntimeStore(str(db)).list_runs() if r['status'] in ('RUNNING', 'BLOCKED')]
