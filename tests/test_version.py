from tests.dsl import Scenario, given, then, when


def test_when_reading_the_package_version(scenario: Scenario) -> None:
    given.the_grants_package(scenario)
    when.its_version_is_read(scenario)
    then.the_version_is(scenario, "0.0.0")
