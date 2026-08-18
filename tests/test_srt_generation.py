import unittest
import os

class TestSRTGeneration(unittest.TestCase):
    def setUp(self):
        self.script_path = os.path.join(os.path.dirname(__file__), '..', 'scripts', 'build_headless_movie.py')
        with open(self.script_path, 'r') as f:
            self.code = f.read()

    def test_srt_formatting_rules(self):
        """Verify that Date and Time are stripped and Depth/Temp format is used."""
        expected_format = "f\"Depth: {row['Depth']}m | Temp: {row['Temperature']}C\\n\\n\""

        self.assertIn(expected_format, self.code, "SRT generation must NOT include Date/Time. It should only be Depth and Temp.")

    def test_srt_alignment_rules(self):
        """Verify that Legacy SSA Top-Right alignment (7) and tight margins (15) are enforced."""
        expected_style = "force_style='FontSize=5,Alignment=7,BorderStyle=3,Outline=1,Shadow=0,MarginV=15,MarginR=15,FontName=Arial'"

        self.assertIn(expected_style, self.code, "FFmpeg subtitles filter must enforce FontSize=5, Alignment=7 (Top-Right), and MarginV=15, MarginR=15.")

if __name__ == "__main__":
    unittest.main()
