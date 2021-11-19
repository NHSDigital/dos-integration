import random

from event_processor.nhs import NHSEntity

test_attr_names = ("ODSCode", "Website", "PublicPhone", "Phone", "Postcode")


def test__init__():

    # Create dict of fake random data
    test_data = {}
    for attr_name in test_attr_names:
        random_str = "".join(random.choices("ABCDEFGHIJKLM", k=8))
        test_data[attr_name] = random_str

    # Create test object
    nhs_entity = NHSEntity(test_data)

    # Check all attributes have been assigned in new object
    for attr_name, value in test_data.items():
        assert getattr(nhs_entity, attr_name) == test_data[attr_name]


def test_ods5():

    # Create dict of fake random data
    test_data = {}
    for attr_name in test_attr_names:
        random_str = "".join(random.choices("ABCDEFGHIJKLM", k=8))
        test_data[attr_name] = random_str

    # Create test object
    nhs_entity = NHSEntity(test_data)

    # change specific ODSCode
    nhs_entity.ODSCode = "SLC82738272"

    # Check output
    assert nhs_entity.ods5() == "SLC82"
