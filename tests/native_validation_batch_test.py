import importlib.util
import pathlib
import subprocess
import sys
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "tools/native-validation/run-check-batch.py"


def load_module():
    spec = importlib.util.spec_from_file_location("run_check_batch", SCRIPT)
    if spec is None or spec.loader is None:
        raise AssertionError("无法加载批量检查模块")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


class NativeValidationBatchContracts(unittest.TestCase):
    def test_manifest_covers_all_formula_check_products_once(self):
        module = load_module()
        checks = module.checks(pathlib.Path("/tmp/lutcalc-release"))
        keys = [item.key for item in checks]
        self.assertEqual(
            keys,
            ["rec709", "slog3", "logc4", "vlog", "applelog", "hlg", "bt1886"],
        )
        self.assertEqual(len(keys), len(set(keys)))
        self.assertEqual(
            [item.executable.name for item in checks],
            [
                "LUTRec709Checks",
                "LUTSLog3Checks",
                "LUTLogC4Checks",
                "LUTVLogChecks",
                "LUTAppleLogChecks",
                "LUTHLGChecks",
                "LUTBT1886Checks",
            ],
        )

    def test_manifest_keeps_fixture_arguments_explicit(self):
        module = load_module()
        checks = {item.key: item for item in module.checks(pathlib.Path("/tmp/bin"))}
        self.assertEqual(
            checks["rec709"].arguments,
            (
                "tests/fixtures/native-contracts/rec709-itu-reference.json",
                "tests/fixtures/native-contracts/rec709-legacy-reference.json",
            ),
        )
        self.assertEqual(
            checks["slog3"].arguments,
            (
                "tests/fixtures/native-contracts/slog3-sony-reference.json",
                "tests/fixtures/native-contracts/slog3-legacy-reference.json",
                "tests/fixtures/native-contracts/slog3-sgamut3cine-ap0-reference.json",
                "tests/fixtures/native-contracts/slog3-sgamut3-ap0-reference.json",
            ),
        )
        self.assertEqual(checks["hlg"].arguments, ())
        self.assertEqual(checks["bt1886"].arguments, ())

    def test_invalid_worker_count_is_rejected_before_execution(self):
        completed = subprocess.run(
            [sys.executable, str(SCRIPT), "/tmp/missing", "--workers", "0"],
            cwd=ROOT,
            text=True,
            capture_output=True,
        )
        self.assertEqual(completed.returncode, 2)
        self.assertIn("must be positive", completed.stderr)

    def test_missing_product_is_rejected_before_batch(self):
        module = load_module()
        with self.assertRaises(module.BatchFailure):
            module.validate_products(module.checks(pathlib.Path("/tmp/missing")))


if __name__ == "__main__":
    unittest.main()
