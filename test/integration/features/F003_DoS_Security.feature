Feature: F003. Endpoint security and reporting

  @complete @security @pharmacy_smoke_test @pharmacy_no_log_searches
  Scenario: F003S001. No api key sent to change event endpoint
    Given a "pharmacy" Changed Event is aligned with DoS
    When the Changed Event is sent for processing with "invalid" api key
    Then the change event response has status code "403"
    And the Slack channel shows an alert saying "DI 4XX Endpoint Errors" from "SHARED_ENVIRONMENT"
