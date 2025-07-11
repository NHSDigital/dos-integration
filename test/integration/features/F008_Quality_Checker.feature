Feature: F008. Check DoS data quality

  @complete @slack_and_infrastructure @quality_checker
  Scenario Outline: F008SX01. Check for too many services
    Given <service_count> <service_status> services of type <service_type> for an odscode starting with A
    When the quality checker is run
    Then the following <reason> is reported <service_count> times

    Examples:
      | service_count | service_status | service_type | reason                                             |
      | 2             | active         | 148          | Multiple 'Pharmacy' type services found (type 148) |
      | 2             | active         | 149          | Multiple 'Pharmacy' type services found (type 149) |

  @complete @slack_and_infrastructure @quality_checker
  Scenario Outline: F008SX02. Check for not too many services
    Given <service_count> <service_status> services of type <service_type> for an odscode starting with A
    When the quality checker is run
    Then the following <reason> is not reported

    Examples:
      | service_count | service_status | service_type | reason                                             |
      | 2             | closed         | 148          | Multiple 'Pharmacy' type services found (type 148) |
      | 2             | commissioning  | 148          | Multiple 'Pharmacy' type services found (type 148) |
      | 2             | closed         | 149          | Multiple 'Pharmacy' type services found (type 149) |
      | 2             | commissioning  | 149          | Multiple 'Pharmacy' type services found (type 149) |

  @complete @slack_and_infrastructure @quality_checker
  Scenario Outline: F008SX03. Palliative on correct service type with incorrect odscode length
    Given an active service of type <service_type> for a <character_count> character odscode starting with A
    And the service in DoS supports palliative care
    When the quality checker is run
    Then the following <reason> is reported 1 times with a long odscode

    Examples:
      | service_type | character_count | reason                                                                                        |
      | 13           | 6               | Palliative Care ZCode is on the correct service type, but the service is incorrectly profiled |


  @complete @slack_and_infrastructure @quality_checker
  Scenario Outline: F008SX04. Blood Pressure/Contraception/Palliative Care on a non-blood pressure/non-contraception/non-palliative care service type does report
    Given <service_count> <service_status> services of type <service_type> for an odscode starting with A
    And the DoS service has <commissioned_service> Z code
    When the quality checker is run
    Then the following <reason> is reported <service_count> times

    Examples:
      | commissioned_service | service_type | service_count | service_status | reason                                           |
      | blood pressure       | 13           | 1             | active         | Blood Pressure ZCode is on invalid service type  |
      | blood pressure       | 131          | 1             | active         | Blood Pressure ZCode is on invalid service type  |
      | blood pressure       | 132          | 1             | active         | Blood Pressure ZCode is on invalid service type  |
      | blood pressure       | 134          | 1             | active         | Blood Pressure ZCode is on invalid service type  |
      | blood pressure       | 137          | 1             | active         | Blood Pressure ZCode is on invalid service type  |
      | blood pressure       | 149          | 1             | active         | Blood Pressure ZCode is on invalid service type  |
      | contraception        | 13           | 1             | active         | Contraception ZCode is on invalid service type   |
      | contraception        | 131          | 1             | active         | Contraception ZCode is on invalid service type   |
      | contraception        | 132          | 1             | active         | Contraception ZCode is on invalid service type   |
      | contraception        | 134          | 1             | active         | Contraception ZCode is on invalid service type   |
      | contraception        | 137          | 1             | active         | Contraception ZCode is on invalid service type   |
      | contraception        | 148          | 1             | active         | Contraception ZCode is on invalid service type   |
      | palliative care      | 131          | 1             | active         | Palliative Care ZCode is on invalid service type |
      | palliative care      | 132          | 1             | active         | Palliative Care ZCode is on invalid service type |
      | palliative care      | 137          | 1             | active         | Palliative Care ZCode is on invalid service type |
      | palliative care      | 148          | 1             | active         | Palliative Care ZCode is on invalid service type |
      | palliative care      | 149          | 1             | active         | Palliative Care ZCode is on invalid service type |


  @complete @slack_and_infrastructure @quality_checker
  Scenario Outline: F008SX05. Blood Pressure/Contraception on a blood pressure/contraception service type does not report
    Given <service_count> <service_status> services of type <service_type> for an odscode starting with A
    And the DoS service has <commissioned_service> Z code
    When the quality checker is run
    Then the following <reason> is not reported

    Examples:
      | commissioned_service | service_type | service_count | service_status | reason                                           |
      | blood pressure       | 148          | 1             | active         | Blood Pressure ZCode is on invalid service type  |
      | contraception        | 149          | 1             | active         | Contraception ZCode is on invalid service type   |
      | palliative care      | 13           | 1             | active         | Palliative Care ZCode is on invalid service type |
      | palliative care      | 134          | 1             | active         | Palliative Care ZCode is on invalid service type |


  @complete @slack_and_infrastructure @quality_checker
  Scenario Outline: F008SX06. Palliative on correct service type with correct odscode length does not report
    Given an active service of type <service_type> for a <character_count> character odscode starting with A
    And the service in DoS supports palliative care
    When the quality checker is run
    Then the following <reason> is not reported

    Examples:
      | service_type | character_count | reason                                                                                        |
      | 13           | 5               | Palliative Care ZCode is on the correct service type, but the service is incorrectly profiled |
