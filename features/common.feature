Feature: Stuff where none of the more specific features matter.

  Scenario: Example configuration.

    Let's validate that the example configuration from the etc directory actually
    parses, and that the address and service objects are unpacked into ipsets correctly.

    Given addresses table from etc
      And services table from etc
      And interfaces table from etc
      And rules table from etc
      And virtuals table from etc
     Then the rules compile
      And these rules exist
        """
        ipset create 'google_v4' hash:net family inet hashsize 1024 maxelem 65536
        ipset add    'google_v4' '216.58.207.238'
        ipset create 'google_v6' hash:net family inet6 hashsize 1024 maxelem 65536
        ipset add    'google_v6' '2a00:1450:400f:80c::200e'
        ipset create 'lan_home_v4' hash:net family inet hashsize 1024 maxelem 65536
        ipset add    'lan_home_v4' '192.168.0.0/24'
        ipset create 'lan_home_v6' hash:net family inet6 hashsize 1024 maxelem 65536
        ipset add    'lan_home_v6' '2a01::1111:1'
        ipset create 'http_tcp' bitmap:port range 1-65535
        ipset add    'http_tcp' '80'
        ipset create 'mumble_tcp' bitmap:port range 1-65535
        ipset add    'mumble_tcp' '64738'
        ipset create 'mumble_udp' bitmap:port range 1-65535
        ipset add    'mumble_udp' '64738'
        """
