import unittest
from unittest.mock import patch, MagicMock
import os
import sys

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from scripts.check_videos import analyze_videos_in_window, get_meta

class TestCheckVideos(unittest.TestCase):

    @patch('scripts.check_videos.subprocess.run')
    def test_get_meta_success(self, mock_run):
        mock_res = MagicMock()
        mock_res.stdout = '{"format": {"duration": "10.5", "tags": {"creation_time": "2026-06-06T10:00:00.000000Z"}}}'
        mock_run.return_value = mock_res

        meta = get_meta("test.mp4", ffprobe_path="ffprobe")
        self.assertIsNotNone(meta)
        self.assertEqual(meta['dur'], 10.5)
        self.assertEqual(meta['ts'], 1780740000.0) # 2026-06-06 10:00:00 UTC
        self.assertEqual(meta['path'], "test.mp4")

    @patch('scripts.check_videos.glob.glob')
    @patch('scripts.check_videos.get_meta')
    def test_analyze_videos_in_window(self, mock_get_meta, mock_glob):
        mock_glob.return_value = ['vid1.MP4', 'vid2.MP4', 'lowres.MP4']

        def mock_meta_side_effect(f):
            if 'vid1' in f: return {'ts': 1000, 'dur': 10, 'path': 'vid1.MP4'}
            if 'vid2' in f: return {'ts': 3000, 'dur': 10, 'path': 'vid2.MP4'}
            return None

        mock_get_meta.side_effect = mock_meta_side_effect

        # Window covers vid1 but not vid2
        videos = analyze_videos_in_window("media_dir", 500, 2000)

        self.assertEqual(len(videos), 1)
        self.assertEqual(videos[0]['path'], 'vid1.MP4')

if __name__ == "__main__":
    unittest.main()
