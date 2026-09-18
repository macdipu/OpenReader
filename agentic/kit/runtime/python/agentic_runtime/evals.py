"""Compare real specialist outputs against eval cases; never a stub pass.

An eval case names what a real handoff envelope (agentic/kit/skills/RESULT-CONTRACT.md)
must and must not look like. Callers supply the *actual* envelope a specialist run
really produced (a recorded run result, or one just returned by an adapter) -
this module never invents or simulates that output itself. A case with no actual
output recorded, an envelope with the wrong status, empty evidence on a ready
result, or an unrecognized status string are all failures, not silent passes.
"""

from .contracts import validate_result


def evaluate_case(case, actual):
    """Evaluate one real ``actual`` handoff envelope against ``case``'s expectations.

    ``case`` fields (all optional except ``id``):
      - ``expect_status``: allowed statuses (e.g. ``["READY"]``)
      - ``forbid_status``: statuses that must not appear
      - ``min_evidence``: minimum number of evidence entries required
      - ``require_output_keys``: keys that must be present in ``outputs``
    """
    reasons = []
    try:
        validate_result(actual)
    except ValueError as exc:
        reasons.append('invalid envelope: ' + str(exc))
    else:
        status = actual.get('status')
        allowed = case.get('expect_status')
        if allowed and status not in allowed:
            reasons.append('expected status in %s, got %r' % (allowed, status))
        forbidden = case.get('forbid_status') or []
        if status in forbidden:
            reasons.append('status %r is forbidden for this case' % status)
        min_evidence = case.get('min_evidence', 0)
        evidence = actual.get('evidence') or []
        if len(evidence) < min_evidence:
            reasons.append('expected at least %d evidence item(s), got %d' % (min_evidence, len(evidence)))
        outputs = actual.get('outputs') or {}
        for key in case.get('require_output_keys', []):
            if key not in outputs:
                reasons.append('outputs missing required key %r' % key)
    return {'id': case['id'], 'verdict': 'FAIL' if reasons else 'PASS', 'reasons': reasons}


def run_eval_suite(cases, actuals):
    """Evaluate every case against its real recorded output.

    ``actuals`` maps case id to the real envelope produced for it. A case with
    no entry fails outright rather than being skipped, so a missing or empty
    output cannot pass by omission.
    """
    results = []
    for case in cases:
        if case['id'] not in actuals:
            results.append({'id': case['id'], 'verdict': 'FAIL', 'reasons': ['no actual output recorded for this case']})
            continue
        results.append(evaluate_case(case, actuals[case['id']]))
    passed = sum(1 for entry in results if entry['verdict'] == 'PASS')
    return {'total': len(results), 'passed': passed, 'failed': len(results) - passed, 'results': results}
