import importlib.util
import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch


DAEMON_PATH = Path(__file__).with_name("DAMX-Daemon.py")


def load_daemon_module():
    spec = importlib.util.spec_from_file_location("damx_daemon", DAEMON_PATH)
    module = importlib.util.module_from_spec(spec)
    with (
        patch("os.geteuid", return_value=0),
        patch("logging.handlers.RotatingFileHandler"),
    ):
        spec.loader.exec_module(module)
    return module


damx = load_daemon_module()


class ThermalProfilePathTests(unittest.TestCase):
    def manager(self):
        manager = damx.DAMXManager.__new__(damx.DAMXManager)
        manager.base_path = (
            "/sys/module/linuwu_sense/drivers/platform:acer-wmi/"
            "acer-wmi/predator_sense"
        )
        return manager

    def test_prefers_complete_damx_profile_pair(self):
        manager = self.manager()
        expected = {
            os.path.join(manager.base_path, "damx_thermal_profile"),
            os.path.join(manager.base_path, "damx_thermal_profile_choices"),
        }

        with patch("os.path.exists", side_effect=lambda path: path in expected):
            profile, choices = manager._get_thermal_profile_paths()

        self.assertEqual(profile, os.path.join(manager.base_path, "damx_thermal_profile"))
        self.assertEqual(choices, os.path.join(manager.base_path, "damx_thermal_profile_choices"))

    def test_falls_back_when_custom_pair_is_incomplete(self):
        manager = self.manager()
        profile_path = os.path.join(manager.base_path, "damx_thermal_profile")

        with patch("os.path.exists", side_effect=lambda path: path == profile_path):
            profile, choices = manager._get_thermal_profile_paths()

        self.assertEqual(profile, "/sys/firmware/acpi/platform_profile")
        self.assertEqual(choices, "/sys/firmware/acpi/platform_profile_choices")

    def test_profile_methods_use_selected_paths(self):
        manager = self.manager()
        manager.available_features = {"thermal_profile"}

        with tempfile.TemporaryDirectory() as tmpdir:
            profile_path = Path(tmpdir, "profile")
            choices_path = Path(tmpdir, "choices")
            profile_path.write_text("balanced\n", encoding="ascii")
            choices_path.write_text(
                "quiet balanced balanced-performance performance\n",
                encoding="ascii",
            )
            manager.thermal_profile_path = str(profile_path)
            manager.thermal_profile_choices_path = str(choices_path)

            self.assertEqual(manager.get_thermal_profile(), "balanced")
            self.assertEqual(
                manager.get_thermal_profile_choices(),
                ["quiet", "balanced", "balanced-performance", "performance"],
            )
            self.assertTrue(manager.set_thermal_profile("quiet"))
            self.assertEqual(profile_path.read_text(encoding="ascii"), "quiet")


if __name__ == "__main__":
    unittest.main()
