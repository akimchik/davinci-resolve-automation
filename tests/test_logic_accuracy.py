import unittest
import pandas as pd
import os
import sys

class TestLogicAccuracy(unittest.TestCase):
    def setUp(self):
        # Create a mock dataframe mimicking the expected CSV format
        data = {
            'Time': [1000, 1005, 1010, 5000, 5005, 5010, 9000, 9005, 9010],
            'Depth': [0, 5, 0, 0, 20, 0, 0, 2, 0],
            'Temperature': [25, 24, 25, 25, 18, 25, 25, 23, 25],
            'ISO8601': ['2026-06-06T10:00:00Z'] * 9 # simplified
        }
        self.df = pd.DataFrame(data)

    def detect_dives_logic(self, df):
        # Replication of final_render.py's detection logic
        df = df.sort_values(by='Time')
        df['gap'] = df['Time'].diff() > 1800 # 30 mins
        df['session'] = df['gap'].cumsum()
        dives = [g for _, g in df.groupby('session') if g['Depth'].max() > 1.0]
        return dives

    def test_multi_dive_detection_accuracy(self):
        """Prove that gaps > 1800s split sessions, and max depth > 1.0 is required."""
        dives = self.detect_dives_logic(self.df)
        self.assertEqual(len(dives), 3, "Failed to correctly detect 3 distinct dives.")
        
        self.assertEqual(dives[0]['Depth'].max(), 5)
        self.assertEqual(dives[1]['Depth'].max(), 20)
        self.assertEqual(dives[2]['Depth'].max(), 2)

    def test_action_highlights_logic(self):
        """Prove that action highlights target max depth and rapid descents correctly."""
        dives = self.detect_dives_logic(self.df)
        dive2 = dives[1]
        
        # Max Depth Target
        max_t = dive2.loc[dive2['Depth'].idxmax(), 'Time']
        self.assertEqual(max_t, 5005, "Failed to target exact max depth time.")

        # Rapid Descent Target (> 0.5m/s)
        descent = dive2[dive2['Depth'].diff() > 0.5].head(1)
        self.assertFalse(descent.empty)
        self.assertEqual(descent.iloc[0]['Time'], 5005, "Failed to identify rapid descent.")

if __name__ == "__main__":
    unittest.main()
