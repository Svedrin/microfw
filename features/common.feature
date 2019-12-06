Feature: Stuff where none of the more specific features matter.

  Scenario: Example configuration.

    Given addresses table from etc
      And services table from etc
      And interfaces table from etc
      And rules table from etc
      And virtuals table from etc
     Then the rules compile
