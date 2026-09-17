import json
import os
import tempfile
from contextlib import contextmanager
from pathlib import Path
from typing import Dict, List, Optional

from .security import redact_value
from .models import WorkflowRun


def _empty_record():
    return {
        'run': None,
        'checkpoints': [],
        'approvals': [],
        'timing_events': [],
        'audit_events': [],
        'tool_calls': {},
    }


class RuntimeStore:
    """Local governed-run persistence: one plain JSON file per run.

    Deliberately not SQLite: a run's full history (state, checkpoints,
    approvals, timing, audit trail) lives in one diffable, mergeable,
    human-readable file under ``<root>/runs/<run_id>.json`` instead of a
    binary database. That makes it possible to commit a completed run's
    file to git for cross-machine reference without fighting binary merge
    conflicts. Active/in-flight runs are still expected to stay out of git
    (see the project's .gitignore) -- the file format changing doesn't
    change the "don't sync mid-flight state" guidance, it only makes doing
    so a text diff instead of an opaque one, for whoever chooses to.

    ``transaction()`` gives callers the same all-or-nothing guarantee the
    prior SQLite implementation gave via SQL transactions: mutations made
    inside a transaction are buffered in memory and only written to disk
    if the block completes without raising; on an exception, the touched
    runs' in-memory state is discarded so the next read falls back to
    whatever was last durably written.
    """

    def __init__(self, db_path: str):
        self.db_path = db_path
        self.root = Path(db_path)
        self.runs_dir = self.root / 'runs'
        self.runs_dir.mkdir(parents=True, exist_ok=True)
        self._cache: Dict[str, dict] = {}
        self._dirty: set = set()
        self._transaction_depth = 0

    def close(self):
        """No-op: nothing to close for a plain-file store; kept for API parity
        with call sites written against the previous SQLite-backed store."""
        pass

    def _path_for(self, run_id: str) -> Path:
        return self.runs_dir / (run_id + '.json')

    def _read(self, run_id: str) -> dict:
        path = self._path_for(run_id)
        return json.loads(path.read_text()) if path.is_file() else _empty_record()

    def _load(self, run_id: str) -> dict:
        """Fetch a run's record to read or mutate.

        Only caches while a transaction is open, and only for that
        transaction's lifetime (read-your-own-writes across multiple calls
        in the same ``with store.transaction():`` block). Outside a
        transaction this always re-reads from disk: hooks and the CLI run
        as separate processes, each with its own RuntimeStore instance, so
        a persistent cache would go stale the moment another process
        writes -- which is exactly what a PreToolUse/PreCompact hook is.
        """
        if self._transaction_depth and run_id in self._cache:
            return self._cache[run_id]
        record = self._read(run_id)
        if self._transaction_depth:
            self._cache[run_id] = record
        return record

    def _touch(self, run_id: str, record: dict):
        if self._transaction_depth:
            self._cache[run_id] = record
            self._dirty.add(run_id)
        else:
            self._flush(run_id, record)

    def _flush(self, run_id: str, record: dict):
        path = self._path_for(run_id)
        fd, temporary = tempfile.mkstemp(prefix='.store-', dir=self.runs_dir)
        try:
            with os.fdopen(fd, 'w') as handle:
                json.dump(record, handle)
                handle.flush()
                os.fsync(handle.fileno())
            os.replace(temporary, path)
        finally:
            Path(temporary).unlink(missing_ok=True)

    # -- run lifecycle ----------------------------------------------------

    def save_run(self, run: WorkflowRun):
        record = self._load(run.run_id)
        record['run'] = run.to_dict()
        self._touch(run.run_id, record)

    def get_run(self, run_id: str) -> Optional[WorkflowRun]:
        record = self._load(run_id)
        if record['run'] is None:
            return None
        return WorkflowRun(**record['run'])

    def list_runs(self) -> List[Dict]:
        runs = []
        for path in self.runs_dir.glob('*.json'):
            record = self._load(path.stem)
            if record['run'] is None:
                continue
            data = dict(record['run'])
            data['metadata_json'] = json.dumps(data.pop('metadata'))
            data['dry_run'] = int(bool(data['dry_run']))
            runs.append(data)
        runs.sort(key=lambda r: r['created_at'], reverse=True)
        return runs

    # -- checkpoints / approvals / timing / audit --------------------------

    def checkpoint(self, run_id, stage, status, payload, ts):
        record = self._load(run_id)
        record['checkpoints'].append({'stage': stage, 'status': status, 'payload': payload, 'created_at': ts})
        self._touch(run_id, record)

    def approval(self, run_id, gate, approver, decision, comment, ts, scope_revision=-1):
        if not self.get_run(run_id):
            raise ValueError("Unknown run")
        if gate not in {"technical", "release", "uat"} or decision not in {"APPROVED", "REJECTED", "REVOKED"} or not approver.strip():
            raise ValueError("Invalid approval record")
        record = self._load(run_id)
        record['approvals'].append({'gate': gate, 'approver': approver, 'decision': decision,
                                     'comment': comment, 'created_at': ts, 'scope_revision': scope_revision})
        self._touch(run_id, record)

    def has_approval(self, run_id, gate, scope_revision=None) -> bool:
        if scope_revision is None:
            run = self.get_run(run_id)
            scope_revision = run.metadata.get("scope_revision", 0) if run else 0
        record = self._load(run_id)
        matching = [a for a in record['approvals'] if a['gate'] == gate and a['scope_revision'] == scope_revision]
        return bool(matching and matching[-1]['decision'] == 'APPROVED')

    def timing(self, run_id, task, event, ts, metadata=None):
        record = self._load(run_id)
        record['timing_events'].append({'task': task, 'event': event, 'ts': ts, 'metadata': redact_value(metadata or {})})
        self._touch(run_id, record)

    def query_timing(self, run_id=None, task=None) -> List[Dict]:
        events = []
        run_ids = [run_id] if run_id is not None else [p.stem for p in self.runs_dir.glob('*.json')]
        for rid in run_ids:
            record = self._load(rid)
            for event in record['timing_events']:
                if task is not None and event['task'] != task:
                    continue
                events.append({'run_id': rid, 'task': event['task'], 'event': event['event'],
                                'ts': event['ts'], 'metadata': event['metadata']})
        events.sort(key=lambda e: e['ts'])
        return events

    def audit(self, run_id, event, payload, ts):
        record = self._load(run_id)
        record['audit_events'].append({'event': event, 'payload': redact_value(payload), 'created_at': ts})
        self._touch(run_id, record)

    def audit_events(self, run_id, event=None) -> List[Dict]:
        record = self._load(run_id)
        events = record['audit_events']
        return [e for e in events if event is None or e['event'] == event]

    # -- tool call idempotency ---------------------------------------------

    def get_tool_call(self, run_id, call_key) -> Optional[Dict]:
        return self._load(run_id)['tool_calls'].get(call_key)

    def start_tool_call(self, run_id, call_key, request_hash):
        record = self._load(run_id)
        record['tool_calls'][call_key] = {'request_hash': request_hash, 'status': 'STARTED', 'result_json': None}
        self._touch(run_id, record)

    def complete_tool_call(self, run_id, call_key, result_json):
        record = self._load(run_id)
        entry = record['tool_calls'].get(call_key)
        if entry is not None:
            entry['status'] = 'COMPLETED'
            entry['result_json'] = result_json
        self._touch(run_id, record)

    def fail_tool_call(self, run_id, call_key):
        record = self._load(run_id)
        entry = record['tool_calls'].get(call_key)
        if entry is not None and entry['status'] == 'STARTED':
            entry['status'] = 'FAILED'
        self._touch(run_id, record)

    # -- transactions -------------------------------------------------------

    @contextmanager
    def transaction(self):
        if self._transaction_depth:
            raise RuntimeError("Nested transactions are unsupported")
        self._transaction_depth = 1
        try:
            yield
            self._transaction_depth = 0
            for run_id in self._dirty:
                self._flush(run_id, self._cache[run_id])
        except BaseException:
            self._transaction_depth = 0
            raise
        finally:
            # Whether committed or rolled back, nothing from this transaction
            # stays cached: a commit's data is now on disk (re-read fresh next
            # time, consistent with reads outside a transaction); a rollback's
            # data was never durable, so evicting it makes the next _load()
            # fall back to whatever was last flushed.
            self._cache.clear()
            self._dirty.clear()

    def save_checkpoint(self, run, event, payload=None):
        # Call inside transaction() so state, checkpoint, and audit commit together.
        if not self._transaction_depth:
            raise RuntimeError("save_checkpoint requires a transaction")
        self.save_run(run)
        self.checkpoint(run.run_id, run.stage, run.status, run.metadata, run.updated_at)
        self.audit(run.run_id, event, payload or {}, run.updated_at)
