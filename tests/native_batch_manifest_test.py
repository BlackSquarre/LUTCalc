import importlib.util
import pathlib
import sys
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT / "tools/native-validation/run-cube-batch.py"
SPEC = importlib.util.spec_from_file_location("run_cube_batch", MODULE_PATH)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC and SPEC.loader
sys.modules["run_cube_batch"] = MODULE
SPEC.loader.exec_module(MODULE)


class NativeBatchManifestTests(unittest.TestCase):
    def test_includes_all_non_hlg_catalog_cube_presets(self):
        manifest = MODULE.cases()
        presets = {case.preset for case in manifest}
        self.assertEqual(len(manifest), 27)
        self.assertEqual(
            presets,
            {
                "dlog2-linear-ap0",
                "dlog2-srgb-w3c",
                "rec709-legacy-exposure",
                "slog3-sony-exposure",
                "slog3-legacy-exposure",
                "slog3-linear-ap0",
                "slog3-sgamut3-linear-ap0",
                "logc4-linear-ap0",
                "vlog-linear-ap0",
                "flog2-exposure",
                "flog2c-exposure",
                "flog2-legacy-exposure",
                "acescct-exposure",
                "acescc-exposure",
                "acesproxy10-exposure",
                "acesproxy12-exposure",
                "ilog-exposure",
                "milog-exposure",
                "llog-exposure",
                "kinelog3-exposure",
                "applelog-linear-ap0",
                "applelog2-linear-ap0",
                "cie-lstar-exposure",
                "prophoto-exposure",
                "bbc-exposure",
                "bbc-whp283-400-exposure",
                "bbc-whp283-800-exposure",
            },
        )


if __name__ == "__main__":
    unittest.main()
