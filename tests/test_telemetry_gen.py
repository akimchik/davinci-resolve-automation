import os
import sys
import unittest
import shutil

# Add the scripts directory to path so we can import generate_telemetry
sys.path.append(os.path.join(os.path.dirname(__file__), "..", "scripts"))
from generate_telemetry import generate_telemetry

class TestTelemetryGenerator(unittest.TestCase):
    def setUp(self):
        # Setup paths
        self.base_dir = os.path.dirname(os.path.dirname(__file__))
        self.logs_dir = "/Volumes/Untitled/DCIM/LOGS/"
        self.test_assets = os.path.join(self.base_dir, "tests", "assets")
        os.makedirs(self.test_assets, exist_ok=True)

        self.out_png = os.path.join(self.test_assets, "test_profile.png")
        self.out_lua = os.path.join(self.test_assets, "test_data.lua")
        self.target_date = "2026-06-07"

    def tearDown(self):
        # Cleanup test assets
        if os.path.exists(self.test_assets):
            shutil.rmtree(self.test_assets)

    def test_generator_execution(self):
        """Verify that the generator produces the required assets."""
        if not os.path.exists(self.logs_dir):
            self.skipTest(f"Camera logs not found at {self.logs_dir}. Skipping integration test.")

        success = generate_telemetry(self.logs_dir, self.target_date, self.out_png, self.out_lua)

        self.assertTrue(success, "Generator failed to execute successfully")
        self.assertTrue(os.path.exists(self.out_png), "PNG asset not generated")
        self.assertTrue(os.path.exists(self.out_lua), "Lua data file not generated")

        # Check Lua file content
        with open(self.out_lua, "r") as f:
            content = f.read()
            self.assertIn("local Telemetry =", content)
            self.assertIn("max_depth =", content)
            self.assertIn("points =", content)

if __name__ == "__main__":
    unittest.main()
