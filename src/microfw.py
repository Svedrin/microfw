#!/usr/bin/env python3

from functools   import reduce
from collections import namedtuple, Counter

Address   = namedtuple("Address",   ["name", "v4", "v6", "lineno"])
Service   = namedtuple("Service",   ["name", "tcp", "udp", "lineno"])
Interface = namedtuple("Interface", ["name", "zone", "protocols", "lineno"])
Rule      = namedtuple("Rule",      ["srczone", "dstzone", "srcaddr", "dstaddr", "service", "action", "lineno"])
Virtual   = namedtuple("Virtual",   ["srczone", "extaddr", "intaddr", "extservice", "intservice", "lineno"])


def read_table(filename):
    columns = {
        "addresses":  3,
        "services":   3,
        "interfaces": 3,
        "rules":      6,
        "virtual":    5
    }

    types = {
        "addresses":  Address,
        "services":   Service,
        "interfaces": Interface,
        "rules":      Rule,
        "virtual":    Virtual
    }

    if filename not in columns:
        raise RuntimeError("table %s does not exist" % filename)

    table = open("etc/" + filename, "r")
    for lineno, line in enumerate(table, start=1):
        if not line.strip() or line.startswith("#"):
            continue
        col_data = line.split()
        if len(col_data) != columns[filename]:
            raise ValueError(
                "%s:%d (%s): Expected %d values, found %d" % (
                    filename, lineno, col_data[0],
                    columns[filename], len(col_data)
                )
            )
        yield types[filename]( *(col_data + [lineno]) )


def printf(fmt, obj):
    """ Format a string using a namedtuple as args. """
    print(fmt % obj._asdict())

def generate_tear_down():
    print('#!/bin/bash')
    print('set -e')
    print('set -u')
    print("")

    # set sane defaults: Delete all rules and user-defined chains, then set the
    # policies to ACCEPT. we will add reject rules down the line, setting the
    # policy to ACCEPT means that the admin can get things to work using
    # iptables -F manually.
    # Then, delete all ipsets.

    print("iptables -F")
    print("iptables -X")
    print("")
    print("iptables -t nat -F")
    print("iptables -t nat -X")
    print("")
    print("iptables -P INPUT   ACCEPT")
    print("iptables -P FORWARD ACCEPT")
    print("iptables -P OUTPUT  ACCEPT")
    print("")
    print("")
    print("ip6tables -F")
    print("ip6tables -X")
    print("")
    print("ip6tables -t nat -F")
    print("ip6tables -t nat -X")
    print("")
    print("ip6tables -P INPUT   ACCEPT")
    print("ip6tables -P FORWARD ACCEPT")
    print("ip6tables -P OUTPUT  ACCEPT")
    print("")
    print("")
    print("ipset flush")
    print("ipset destroy")

def iptables(args):
    print("iptables  %s" % args)
    print("ip6tables %s" % args)

def generate_setup():
    # Parse tables

    all_addresses = {
        address.name: address
        for address in read_table("addresses")
    }
    all_services = {
        service.name: service
        for service in read_table("services")
    }

    all_interfaces = list(read_table("interfaces"))
    all_zones      = set( iface.zone for iface in all_interfaces )
    all_rules      = list(read_table("rules"))
    all_virtuals   = list(read_table("virtual"))

    # Validate interfaces, rules and virtuals

    for interface in all_interfaces:
        if interface.zone in ("FW", "ALL"):
            raise ValueError(
                "interfaces:%d (%s): Interface zone cannot be ALL or FW" % (
                    interface.lineno, interface.name
                )
            )

    for rule in all_rules:
        if rule.action not in ("accept+nat", "accept", "reject", "drop"):
            raise ValueError(
                "rules:%d: Invalid action '%s'" % (
                    rule.lineno, rule.action
                )
            )
        if rule.srczone in ("FW", "ALL"):
            raise ValueError("rules:%d: Source Zone cannot be ALL or FW" % rule.lineno)
        if rule.srczone not in all_zones:
            raise ValueError(
                "rules:%d: Source zone '%s' does not exist" % (
                    rule.lineno, rule.dstzone
                )
            )
        if rule.dstzone not in all_zones | {"FW", "ALL"}:
            raise ValueError(
                "rules:%d: Destination zone '%s' does not exist" % (
                    rule.lineno, rule.dstzone
                )
            )
        if rule.srcaddr != "ALL":
            if rule.srcaddr not in all_addresses:
                raise ValueError(
                    "rules:%d: Source Address '%s' does not exist" % (
                        rule.lineno, rule.srcaddr
                    )
                )
        if rule.dstaddr != "ALL":
            if rule.dstaddr not in all_addresses:
                raise ValueError(
                    "rules:%d: Destination Address '%s' does not exist" % (
                        rule.lineno, rule.dstaddr
                    )
                )
        if rule.service != "ALL":
            if rule.service not in all_services:
                raise ValueError(
                    "rules:%d: Service '%s' does not exist" % (
                        rule.lineno, rule.service
                    )
                )

    # For address and service tables, figure out which entries are actually _used_

    used_addresses = set(
        all_addresses[rule.srcaddr]    for rule    in all_rules    if rule.srcaddr != "ALL"
    ) | set(
        all_addresses[rule.dstaddr]    for rule    in all_rules    if rule.dstaddr != "ALL"
    ) | set(
        all_addresses[virtual.extaddr] for virtual in all_virtuals if virtual.extaddr != "ALL"
    ) | set(
        all_addresses[virtual.intaddr] for virtual in all_virtuals if virtual.intaddr != "ALL"
    )

    used_services = set(
        all_services[rule.service]       for rule    in all_rules    if rule.service != "ALL"
    ) | set(
        all_services[virtual.extservice] for virtual in all_virtuals if virtual.extservice != "ALL"
    ) | set(
        all_services[virtual.intservice] for virtual in all_virtuals if virtual.intservice != "ALL"
    )

    # Now let's generate a bash script.

    print("#!/bin/bash")
    print("set -e")
    print("set -u")
    print("")

    # Generate ipsets for the entries we're going to use

    for address in used_addresses:
        if address.v4 != '-':
            printf("ipset create %(name)s_v4 hash:net family inet  hashsize 1024 maxelem 65536", address)
            printf("ipset add    %(name)s_v4 %(v4)s", address)
        if address.v6 != '-':
            printf("ipset create %(name)s_v6 hash:net family inet6 hashsize 1024 maxelem 65536", address)
            printf("ipset add    %(name)s_v6 %(v6)s", address)

    for service in used_services:
        if service.tcp != '-':
            printf("ipset create %(name)s_tcp hash:net bitmap:port range 1-65535", service)
            printf("ipset add    %(name)s_tcp %(tcp)s", service)
        if service.udp != '-':
            printf("ipset create %(name)s_udp hash:net bitmap:port range 1-65535", service)
            printf("ipset add    %(name)s_udp %(udp)s", service)

    # Generate implicit accept rules for lo, icmp and related

    print("iptables -A INPUT   -i lo   -j ACCEPT")
    print("iptables -A INPUT   -p icmp -j ACCEPT")
    print("iptables -A FORWARD -p icmp -j ACCEPT")
    print("")
    print("ip6tables -A INPUT   -i lo     -j ACCEPT")
    print("ip6tables -A INPUT   -p icmpv6 -j ACCEPT")
    print("ip6tables -A FORWARD -p icmpv6 -j ACCEPT")
    print("")
    print("iptables  -A INPUT   -m state --state RELATED,ESTABLISHED -j ACCEPT")
    print("ip6tables -A INPUT   -m state --state RELATED,ESTABLISHED -j ACCEPT")
    print("iptables  -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT")
    print("ip6tables -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT")

    # Generate action chains

    print("iptables -N accept")
    print("iptables -A accept -j ACCEPT")
    print("")
    print("iptables -N drop")
    print("iptables -A drop -j DROP")
    print("")
    print("iptables -N reject")
    print("iptables -A reject -m addrtype --src-type BROADCAST -j DROP")
    print("iptables -A reject -s 224.0.0.0/4 -j DROP")
    print("iptables -A reject -p igmp -j DROP")
    print("iptables -A reject -p tcp -j REJECT --reject-with tcp-reset")
    print("iptables -A reject -p udp -j REJECT --reject-with icmp-port-unreachable")
    print("iptables -A reject -p icmp -j REJECT --reject-with icmp-host-unreachable")
    print("iptables -A reject -j REJECT --reject-with icmp-host-prohibited")
    print("")
    print("ip6tables -N accept")
    print("ip6tables -A accept -j ACCEPT")
    print("")
    print("ip6tables -N drop")
    print("ip6tables -A drop -j DROP")
    print("")
    print("ip6tables -N reject")
    print("ip6tables -A reject -p tcp -j REJECT --reject-with tcp-reset")
    print("ip6tables -A reject -j REJECT --reject-with icmp6-adm-prohibited")

    # Generate zone-specific chains

    for zone in all_zones:
        print("iptables  -N '%s_inp'" % zone)
        print("ip6tables -N '%s_inp'" % zone)
        print("iptables  -N '%s_fwd'" % zone)
        print("ip6tables -N '%s_fwd'" % zone)
        print("")

    # Generate rules to route traffic from INPUT and FORWARD to those chains

    for interface in all_interfaces:
        for proto in interface.protocols.split(","):
            print("iptables  -A INPUT   -i '%s' -p '%s' -j ACCEPT" % (interface.name, proto))
            print("ip6tables -A INPUT   -i '%s' -p '%s' -j ACCEPT" % (interface.name, proto))

        # Route incoming traffic to zone-specific input chains
        printf("iptables  -A INPUT   -i '%(name)s' -j '%(zone)s_inp'", interface)
        printf("ip6tables -A INPUT   -i '%(name)s' -j '%(zone)s_inp'", interface)

        # We will never allow hairpin traffic though (traffic cannot be
        # forwarded out the same interface where it came in)
        printf("iptables  -A FORWARD -i '%(name)s' -o '%(name)s' -j drop", interface)
        printf("ip6tables -A FORWARD -i '%(name)s' -o '%(name)s' -j drop", interface)

        # Route incoming traffic to zone-specific forward chains
        printf("iptables  -A FORWARD -i '%(name)s' -j '%(zone)s_fwd'", interface)
        printf("ip6tables -A FORWARD -i '%(name)s' -j '%(zone)s_fwd'", interface)

    # Generate rules to implement filtering

    for rule in all_rules:
        # cmd is a dictionary that contains all the necessary building blocks for
        # an iptables command.
        # We're gonna pass it through a bunch of generators that each yield a
        # number of combinations for ipv4/ipv6 addresses, tcp/udp services and
        # accept/masquerade rules.
        # So the number of combinations grows with each step along the way.
        # At the end, every combination gets passed into render_cmd which
        # turns it into a string.

        def iptables(cmd=None):
            yield dict(cmd="iptables",  table="filter")
            yield dict(cmd="ip6tables", table="filter")

        def chains(cmd):
            # Find out which input/forward chains we need to use
            if rule.dstzone == "ALL":
                dstzones = all_zones | {"FW"}
            else:
                dstzones = [rule.dstzone]

            for dstzone in dstzones:
                # Destination ALL or FW: goto <src>_inp
                if dstzone in ("FW", "ALL"):
                    yield dict(cmd,
                        chain="%s_inp" % rule.srczone,
                        iface=""
                    )

                # Destination ALL or specific zone: goto <src>_fwd
                for interface in all_interfaces:
                    if dstzone in (interface.zone, "ALL"):
                        yield dict(cmd,
                            chain="%s_fwd" % rule.srczone,
                            iface="%s" % interface.name
                        )

        def address(addr, direction):
            def _filter_addr(cmd):
                if addr == "ALL":
                    yield cmd
                elif cmd["cmd"] == "iptables":
                    if all_addresses[addr].v4 != '-':
                        yield dict(cmd, **{ "%saddr" % direction : "%s_v4" % addr })
                else:
                    if all_addresses[addr].v6 != '-':
                        yield dict(cmd, **{ "%saddr" % direction : "%s_v6" % addr })

            return _filter_addr

        def service(cmd):
            if rule.service == "ALL":
                yield cmd
            else:
                if all_services[rule.service].tcp != '-':
                    yield dict(cmd, service='%s_tcp' % rule.service, proto="tcp")
                if all_services[rule.service].udp != '-':
                    yield dict(cmd, service='%s_udp' % rule.service, proto="udp")

        def action(cmd):
            action = "accept" if rule.action == "accept+nat" else rule.action
            yield dict(cmd, action=action)

        def masq(cmd):
            yield cmd
            if rule.action == "accept+nat":
                yield dict(cmd, table="nat", chain="POSTROUTING", action="MASQUERADE")

        def render_cmd(cmd):
            fmt = "%(cmd)s -t '%(table)s' -A '%(chain)s' "
            if cmd.get("iface"):
                fmt += "-o '%(iface)s' "
            if cmd.get("srcaddr"):
                fmt += "-m set --match-set '%(srcaddr)s' src "
            if cmd.get("dstaddr"):
                fmt += "-m set --match-set '%(dstaddr)s' dst "
            if cmd.get("service"):
                fmt += "-p '%(proto)s' -m set --match-set '%(service)s' dst "
            fmt += "-j %(action)s"
            yield fmt % cmd

        # Create a pipeline of steps ready to be consumed by reduce.
        # The first element we need to invoke manually.
        # The others are invoked by chain_gen.
        pipeline = [
            iptables(),
            chains,
            address(rule.srcaddr, "src"),
            address(rule.dstaddr, "dst"),
            service,
            action,
            masq,
            render_cmd
        ]

        def chain_gen(cmd_gen, next_gen):
            # Take the results from the last step, and pipe every result
            # into the next step individually.
            for cmd in cmd_gen:
                yield from next_gen(cmd)

        # Now reduce() the pipeline to generate the actual commands.
        for command in reduce(chain_gen, pipeline):
            print(command)


if __name__ == '__main__':
    generate_setup()

