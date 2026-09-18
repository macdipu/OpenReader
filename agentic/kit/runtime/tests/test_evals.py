import unittest

from support import ready
from agentic_runtime.evals import evaluate_case, run_eval_suite

GOOD_INTAKE = ready('TASK-KIT-001.md#requirements-and-evidence', verdict='INTAKE_READY')


class EvalRunnerTests(unittest.TestCase):
    def test_real_ready_output_passes(self):
        case = {'id': 'intake', 'expect_status': ['READY'], 'min_evidence': 1}
        self.assertEqual(evaluate_case(case, GOOD_INTAKE)['verdict'], 'PASS')

    def test_wrong_status_fails(self):
        case = {'id': 'intake', 'expect_status': ['READY']}
        actual = dict(GOOD_INTAKE, status='BLOCKED', evidence=[], blocking_issues=['dependency missing'])
        result = evaluate_case(case, actual)
        self.assertEqual(result['verdict'], 'FAIL')
        self.assertTrue(any('expected status' in reason for reason in result['reasons']))

    def test_empty_evidence_on_ready_fails(self):
        case = {'id': 'intake', 'expect_status': ['READY'], 'min_evidence': 1}
        actual = dict(GOOD_INTAKE, evidence=[])
        # contracts.validate_result already forbids READY with no evidence; the
        # eval runner must surface that as a failure, not treat it as an unrelated case.
        self.assertEqual(evaluate_case(case, actual)['verdict'], 'FAIL')

    def test_unknown_status_fails(self):
        case = {'id': 'intake', 'expect_status': ['READY']}
        actual = dict(GOOD_INTAKE, status='DONE')
        result = evaluate_case(case, actual)
        self.assertEqual(result['verdict'], 'FAIL')
        self.assertTrue(any('unknown result status' in reason.lower() for reason in result['reasons']))

    def test_missing_required_output_key_fails(self):
        case = {'id': 'intake', 'expect_status': ['READY'], 'require_output_keys': ['verdict']}
        actual = dict(GOOD_INTAKE, outputs={})
        result = evaluate_case(case, actual)
        self.assertEqual(result['verdict'], 'FAIL')

    def test_missing_actual_output_fails_rather_than_being_skipped(self):
        report = run_eval_suite([{'id': 'intake', 'expect_status': ['READY']}], {})
        self.assertEqual((report['passed'], report['failed']), (0, 1))

    def test_suite_distinguishes_good_from_bad_output_for_the_same_case(self):
        # Guards against exactly the "misleading eval pass" failure mode named in
        # TASK-KIT-001: a runner that reports PASS regardless of the real output.
        case = {'id': 'intake', 'expect_status': ['READY'], 'min_evidence': 1}
        bad_actual = dict(GOOD_INTAKE, status='BLOCKED', evidence=[], blocking_issues=['broken'])
        good_report = run_eval_suite([case], {'intake': GOOD_INTAKE})
        bad_report = run_eval_suite([case], {'intake': bad_actual})
        self.assertEqual(good_report['failed'], 0)
        self.assertEqual(bad_report['failed'], 1)


if __name__ == '__main__':
    unittest.main()
