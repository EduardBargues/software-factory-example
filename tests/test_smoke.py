"""Smoke test so the brakes (pytest, coverage, mypy) have a target before the
factory builds the app. Replace with behavior tests per docs/app/SPEC.md tiers."""

from grants import __version__


def test_package_exposes_version() -> None:
    assert __version__ == "0.0.0"
