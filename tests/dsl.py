"""Given / When / Then test DSL. A Scenario hides the mocks so tests speak only GLOSSARY terms.

Tense by role: given → future, when → present, then → past. Add domain helpers to the
given / when / then classes as the app grows; keep tests asserting only through `then`.
"""

from pytest_mock import MockerFixture

import grants


class Scenario:
    """Holds a test's mocks and state; only the DSL touches them, never a test body."""

    def __init__(self, mocker: MockerFixture) -> None:
        self.mocker = mocker
        self.version = ""


class _Given:
    def the_grants_package(self, scenario: Scenario) -> None:
        """No arrangement needed — the package always exposes its version."""


class _When:
    def its_version_is_read(self, scenario: Scenario) -> None:
        scenario.version = grants.__version__


class _Then:
    def the_version_is(self, scenario: Scenario, expected: str) -> None:
        assert scenario.version == expected


given = _Given()
when = _When()
then = _Then()
