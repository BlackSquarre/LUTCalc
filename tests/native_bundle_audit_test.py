import importlib.util
import plistlib
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "tools/native-validation/audit-native-bundles.py"
SPEC = importlib.util.spec_from_file_location("native_bundle_audit", SCRIPT)
AUDIT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(AUDIT)


class BundleAuditContracts(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.app = Path(self.directory.name) / "Demo.app"
        executable = self.app / "Contents/MacOS/Demo"
        executable.parent.mkdir(parents=True)
        executable.write_text("#!/bin/sh\n")
        with (self.app / "Contents/Info.plist").open("wb") as output:
            plistlib.dump({"CFBundleExecutable": "Demo"}, output)

    def test_clean_bundle_passes(self):
        self.assertEqual(AUDIT.audit_bundle(self.app), [])

    def test_lut_and_script_resources_are_rejected(self):
        resources = self.app / "Contents/Resources"
        resources.mkdir()
        (resources / "vendor.labin").write_bytes(b"old lookup")
        (resources / "runtime.js").write_text("alert(1)")
        failures = AUDIT.audit_bundle(self.app)
        self.assertTrue(any("vendor.labin" in line for line in failures))
        self.assertTrue(any("runtime.js" in line for line in failures))

    def test_symlink_escape_and_missing_executable_are_rejected(self):
        outside = Path(self.directory.name) / "outside.cube"
        outside.write_text("LUT_3D_SIZE 2")
        (self.app / "Contents/Resources").mkdir()
        (self.app / "Contents/Resources/link").symlink_to(outside)
        self.assertTrue(any("link" in line for line in AUDIT.audit_bundle(self.app)))
        (self.app / "Contents/MacOS/Demo").unlink()
        self.assertTrue(any("executable" in line for line in AUDIT.audit_bundle(self.app)))


if __name__ == "__main__":
    unittest.main()
