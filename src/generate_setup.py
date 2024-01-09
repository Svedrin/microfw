#!/usr/bin/env python3

import sys
import os.path
import itertools

from functools   import reduce
from collections import namedtuple

Tables    = namedtuple("Tables",    ["addresses", "services", "interfaces", "rules", "virtuals"])
Address   = namedtuple("Address",   ["name", "v4", "v6", "lineno"])
Service   = namedtuple("Service",   ["name", "tcp", "udp", "lineno"])
Interface = namedtuple("Interface", ["name", "zone", "protocols", "lineno"])
Rule      = namedtuple("Rule",      ["srczone", "dstzone", "srcaddr", "dstaddr", "service", "action", "lineno"])
Virtual   = namedtuple("Virtual",   ["srczone", "extaddr", "intaddr", "extservice", "intservice", "lineno"])

ETC_DIR = "/etc/microfw"
RUN_DIR = "/run/microfw"

if len(sys.argv) > 1:
    ETC_DIR = sys.argv[1]


def read_table(filename):
    table = open(os.path.join(ETC_DIR, filename), "r")
    yield from parse_table(filename, table)

def parse_table(filename, table):
    columns = {
        "addresses":  3,
        "services":   3,
        "interfaces": 3,
        "rules":      6,
        "virtuals":   5
    }

    types = {
        "addresses":  Address,
        "services":   Service,
        "interfaces": Interface,
        "rules":      Rule,
        "virtuals":   Virtual
    }

    if filename not in columns:
        raise RuntimeError("table %s does not exist" % filename)

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


def ensure_unique(thing, lst):
    # Make sure `lst` contains only unique elements, and raise ValueError
    # if dupes are found.
    def compare(a, b):
        if a == b:
            raise ValueError("duplicate %s: %s" % (thing, b))
        return b
    reduce(compare, sorted(lst))


def chain_gen(cmd_gen, next_gen):
    # Take the results from the last step, and pipe every result
    # into the next step individually.
    for cmd in cmd_gen:
        yield from next_gen(cmd)


def generate_setup(tables):
    output = []

    # Parse tables

    all_addresses = {
        address.name: address
        for address in tables.addresses
    }
    all_services = {
        service.name: service
        for service in tables.services
    }

    all_interfaces = list(tables.interfaces)
    all_zones      = set( iface.zone for iface in all_interfaces )
    all_rules      = list(tables.rules)
    all_virtuals   = list(tables.virtuals)

    # If we have an accept+nat rule that specifies ALL as the src address, we have to use mangle
    use_mangle = bool([
        rule
        for rule in all_rules
        if rule.action == "accept+nat" and rule.srcaddr == "ALL"
    ])

    # Validate interfaces, rules and virtuals

    ensure_unique("interface", [interface.name for interface in all_interfaces])

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
        if rule.srcaddr != "ALL" and not rule.srcaddr.startswith("GEO:"):
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

    for virtual in all_virtuals:
        if virtual.srczone in ("FW", "ALL"):
            raise ValueError(
                "virtuals:%d: Source zone cannot be ALL or FW" % virtual.lineno
            )
        if virtual.extaddr == "ALL":
            raise ValueError("virtuals:%d: External Address cannot be ALL" % virtual.lineno)
        if virtual.extaddr not in all_addresses:
            raise ValueError(
                "virtuals:%d: External Address '%s' does not exist" % (
                    virtual.lineno, virtual.extaddr
                )
            )
        if virtual.intaddr == "ALL":
            raise ValueError("virtuals:%d: Internal Address cannot be ALL" % virtual.lineno)
        if virtual.intaddr not in all_addresses and virtual.intaddr != "DOCKER":
            raise ValueError(
                "virtuals:%d: Internal Address '%s' does not exist" % (
                    virtual.lineno, virtual.intaddr
                )
            )
        if "ALL" in (virtual.extservice, virtual.intservice):
            if virtual.extservice != virtual.intservice:
                raise ValueError(
                    "virtuals:%d: When setting one service to ALL, the other must also be ALL" % (
                        virtual.lineno
                    )
                )
            if virtual.intaddr == "DOCKER":
                raise ValueError(
                    "virtuals:%d: Cannot expose ALL ports to a Docker container (INPUT chain would blow up)" % (
                        virtual.lineno
                    )
                )
        if virtual.extservice != "ALL":
            if virtual.extservice not in all_services:
                raise ValueError(
                    "virtuals:%d: External Service '%s' does not exist" % (
                        virtual.lineno, virtual.extservice
                    )
                )
        if virtual.intservice != "ALL":
            if virtual.intservice not in all_services:
                raise ValueError(
                    "virtuals:%d: Internal Service '%s' does not exist" % (
                        virtual.lineno, virtual.intservice
                    )
                )

    # For address and service tables, figure out which entries are actually _used_

    used_addresses = set(
        all_addresses[rule.srcaddr]    for rule    in all_rules    if rule.srcaddr != "ALL" and
                                                                   not rule.srcaddr.startswith("GEO:")
    ) | set(
        all_addresses[rule.dstaddr]    for rule    in all_rules    if rule.dstaddr != "ALL"
    ) | set(
        all_addresses[virtual.extaddr] for virtual in all_virtuals if virtual.extaddr != "ALL"
    ) | set(
        all_addresses[virtual.intaddr] for virtual in all_virtuals if virtual.intaddr not in ("ALL", "DOCKER")
    )

    used_services = set(
        all_services[rule.service]       for rule    in all_rules    if rule.service != "ALL"
    ) | set(
        all_services[virtual.extservice] for virtual in all_virtuals if virtual.extservice != "ALL"
    ) | set(
        all_services[virtual.intservice] for virtual in all_virtuals if virtual.intservice != "ALL"
    )

    # Now let's generate a bash script.

    def printf(fmt, obj=None):
        """ Format a string using a namedtuple as args. """
        if obj is None:
            output.append(fmt)
        else:
            output.append(fmt % obj._asdict())

    def state(fmt, obj=None):
        """ generate a command to echo something into the state file """
        printf('echo "%s" >> "%s"/state.txt ' % (fmt, RUN_DIR), obj)

    # Generate ipsets for the entries we're going to use

    for address in sorted(used_addresses, key=lambda x: x.name):
        if address.v4 != '-':
            printf("ipset create '%(name)s_v4' hash:net family inet  hashsize 1024 maxelem 65536", address)
            printf("ipset add    '%(name)s_v4' '%(v4)s'", address)
        if address.v6 != '-':
            printf("ipset create '%(name)s_v6' hash:net family inet6 hashsize 1024 maxelem 65536", address)
            printf("ipset add    '%(name)s_v6' '%(v6)s'", address)

    for service in sorted(used_services, key=lambda x: x.name):
        if service.tcp != '-':
            printf("ipset create '%(name)s_tcp' bitmap:port range 1-65535", service)
            printf("ipset add    '%(name)s_tcp' '%(tcp)s'", service)
        if service.udp != '-':
            printf("ipset create '%(name)s_udp' bitmap:port range 1-65535", service)
            printf("ipset add    '%(name)s_udp' '%(udp)s'", service)

    printf("")
    printf("mkdir -p %s"        % RUN_DIR)
    printf("rm -f %s/state.txt" % RUN_DIR)
    printf("touch %s/state.txt" % RUN_DIR)
    printf("chmod 600 %s/state.txt" % RUN_DIR)
    printf("")

    printf("iptables  -t filter -N MFWINPUT")
    printf("ip6tables -t filter -N MFWINPUT")
    printf("iptables  -t filter -N MFWFORWARD")
    printf("ip6tables -t filter -N MFWFORWARD")
    printf("iptables  -t nat    -N MFWPREROUTING")
    printf("ip6tables -t nat    -N MFWPREROUTING")
    printf("iptables  -t nat    -N MFWPOSTROUTING")
    printf("ip6tables -t nat    -N MFWPOSTROUTING")

    if "DOCKER" in all_zones:
        state("HAVE-DOCKER")

    if use_mangle:
        printf("iptables  -t mangle -N MFWFORWARD")
        printf("ip6tables -t mangle -N MFWFORWARD")
        state("HAVE-MANGLE")

    # Generate implicit accept rules for lo, icmp and related

    printf("iptables  -A MFWINPUT   -i lo   -j ACCEPT")
    printf("ip6tables -A MFWINPUT   -i lo   -j ACCEPT")

    printf("iptables  -A MFWINPUT   -m state --state RELATED,ESTABLISHED -j ACCEPT")
    printf("ip6tables -A MFWINPUT   -m state --state RELATED,ESTABLISHED -j ACCEPT")

    printf("iptables  -A MFWFORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT")
    printf("ip6tables -A MFWFORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT")

    # Generate action chains

    printf("iptables  -N accept")
    printf("iptables  -A accept -j ACCEPT")

    printf("iptables  -N drop")
    printf("iptables  -A drop -j DROP")

    printf("iptables  -N reject")
    printf("iptables  -A reject -m addrtype --src-type BROADCAST -j DROP")
    printf("iptables  -A reject -s 224.0.0.0/4 -j DROP")
    printf("iptables  -A reject -p igmp -j DROP")
    printf("iptables  -A reject -p tcp -j REJECT --reject-with tcp-reset")
    printf("iptables  -A reject -p udp -j REJECT --reject-with icmp-port-unreachable")
    printf("iptables  -A reject -p icmp -j REJECT --reject-with icmp-host-unreachable")
    printf("iptables  -A reject -j REJECT --reject-with icmp-host-prohibited")

    printf("ip6tables -N accept")
    printf("ip6tables -A accept -j ACCEPT")

    printf("ip6tables -N drop")
    printf("ip6tables -A drop -j DROP")

    printf("ip6tables -N reject")
    printf("ip6tables -A reject -p tcp -j REJECT --reject-with tcp-reset")
    printf("ip6tables -A reject -j REJECT --reject-with icmp6-adm-prohibited")

    # Generate zone-specific chains

    for zone in sorted(all_zones):
        printf("iptables  -N '%s_inp'" % zone)
        printf("ip6tables -N '%s_inp'" % zone)
        printf("iptables  -N '%s_fwd'" % zone)
        printf("ip6tables -N '%s_fwd'" % zone)
        state("ZONE %s" % zone)

        if use_mangle:
            printf("iptables  -t mangle -N '%s_fwd'" % zone)
            printf("ip6tables -t mangle -N '%s_fwd'" % zone)

    # Generate rules to route traffic from MFWINPUT and MFWFORWARD to those chains

    for interface in all_interfaces:
        if interface.protocols != "-":
            for proto in interface.protocols.split(","):
                printf("iptables  -A MFWINPUT   -i '%s' -p '%s' -j ACCEPT" % (interface.name, proto))
                printf("ip6tables -A MFWINPUT   -i '%s' -p '%s' -j ACCEPT" % (interface.name, proto))

        # Route incoming traffic to zone-specific input chains
        printf("iptables  -A MFWINPUT   -i '%(name)s' -j '%(zone)s_inp'", interface)
        printf("ip6tables -A MFWINPUT   -i '%(name)s' -j '%(zone)s_inp'", interface)

        # We will never allow hairpin traffic though (traffic cannot be
        # forwarded out the same interface where it came in), unless that
        # interface is a bridge, then we accept it
        printf('if [ ! -e "/sys/class/net/%(name)s/bridge/" ]; then', interface)
        printf("  iptables  -A MFWFORWARD -i '%(name)s' -o '%(name)s' -j drop", interface)
        printf("  ip6tables -A MFWFORWARD -i '%(name)s' -o '%(name)s' -j drop", interface)
        printf('else')
        printf("  iptables  -A MFWFORWARD -i '%(name)s' -o '%(name)s' -j ACCEPT", interface)
        printf("  ip6tables -A MFWFORWARD -i '%(name)s' -o '%(name)s' -j ACCEPT", interface)
        printf("fi")

        # Route incoming traffic to zone-specific forward chains
        printf("iptables  -A MFWFORWARD -i '%(name)s' -j '%(zone)s_fwd'", interface)
        printf("ip6tables -A MFWFORWARD -i '%(name)s' -j '%(zone)s_fwd'", interface)

        if use_mangle:
            printf("iptables  -t mangle -A MFWFORWARD -i '%(name)s' -j '%(zone)s_fwd'", interface)
            printf("ip6tables -t mangle -A MFWFORWARD -i '%(name)s' -j '%(zone)s_fwd'", interface)

    # Generate rules to implement filtering
    mark_gen = itertools.count(0x400)

    for rule in all_rules:
        # cmd is a dictionary that contains all the necessary building blocks for
        # an iptables command.
        # We're gonna pass it through a bunch of generators that each yield a
        # number of combinations for ipv4/ipv6 addresses, tcp/udp services and
        # accept/masquerade rules.
        # So the number of combinations grows with each step along the way.
        # At the end, every combination gets passed into render_cmd which
        # turns it into a string.

        def iptables():
            yield dict(cmd="iptables")
            yield dict(cmd="ip6tables")

        def chains(cmd):
            # Find out which input/forward chains we need to use
            # Destination ALL or FW: goto <src>_inp
            if rule.dstzone in ("FW", "ALL"):
                yield dict(cmd,
                    chain="%s_inp" % rule.srczone
                )

            # Destination ALL or specific zone: goto <src>_fwd
            for interface in all_interfaces:
                if rule.dstzone in (interface.zone, "ALL"):
                    yield dict(cmd,
                        chain="%s_fwd" % rule.srczone,
                        iface=interface.name
                    )

        def address(addr, which_one):
            def _filter_addr(cmd):
                if addr == "ALL":
                    yield cmd
                elif addr.startswith("GEO:"):
                    yield dict(cmd, srcgeo=addr.replace("GEO:", ""))
                elif cmd["cmd"] == "iptables":
                    if all_addresses[addr].v4 != '-':
                        yield dict(cmd, **{ "%saddr" % which_one : "%s_v4" % addr })
                else:
                    if all_addresses[addr].v6 != '-':
                        yield dict(cmd, **{ "%saddr" % which_one : "%s_v6" % addr })

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
            if rule.action == "accept+nat":
                yield dict(cmd, action="accept")
                if rule.srcaddr == "ALL":
                    # mark in mangle, masq in postrouting
                    current_mark = next(mark_gen)
                    yield dict(cmd, table="mangle",                         action="MARK",       mark_set=current_mark)
                    yield dict(cmd, table="nat",    chain="MFWPOSTROUTING", action="MASQUERADE", mark_match=current_mark)
                else:
                    # postrouting will suffice
                    yield dict(cmd, table="nat",    chain="MFWPOSTROUTING", action="MASQUERADE")
            else:
                yield dict(cmd, action=rule.action)

        def render_cmd(cmd):
            fmt = "%(cmd)-9s "
            if cmd.get("table"):
                fmt += "-t '%(table)s' "
            fmt += "-A '%(chain)s' "
            if cmd.get("iface"):
                fmt += "-o '%(iface)s' "
            if cmd.get("srcgeo"):
                fmt += "-m geoip --src-cc '%(srcgeo)s' "
            if cmd.get("srcaddr"):
                fmt += "-m set --match-set '%(srcaddr)s' src "
            if cmd.get("dstaddr"):
                fmt += "-m set --match-set '%(dstaddr)s' dst "
            if cmd.get("mark_match"):
                fmt += "-m mark --mark 0x%(mark_match)x "
            if cmd.get("service"):
                fmt += "-p '%(proto)s' -m set --match-set '%(service)s' dst "
            fmt += "-j %(action)s"
            if cmd.get("mark_set"):
                fmt += " --set-mark 0x%(mark_set)x"
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
            render_cmd
        ]

        # Now reduce() the pipeline to generate the actual commands.
        for command in reduce(chain_gen, pipeline):
            printf(command)


    # Generate rules to implement virtual services

    for virtual in all_virtuals:
        # We basically do the same thing we did for rules, but for each entry in virtuals,
        # we need to create _two_ rules:
        # One for MFWPREROUTING to perform the DNAT on the external IPs, and
        # one for MFWFORWARD to allow the traffic that results from this.

        def iptables():
            yield dict(cmd="iptables")
            yield dict(cmd="ip6tables")

        def interfaces(cmd):
            for interface in all_interfaces:
                if interface.zone == virtual.srczone:
                    yield dict(cmd, iface=interface.name)

        def address(addr, which_one):
            def _filter_addr(cmd):
                # Passthrough DOCKER as a string; resolve everything else
                if which_one == "int" and addr == "DOCKER":
                    yield dict(cmd, intaddr="DOCKER")
                elif cmd["cmd"] == "iptables":
                    if all_addresses[addr].v4 != '-':
                        yield dict(cmd, **{ "%saddr" % which_one : all_addresses[addr].v4 })
                else:
                    if all_addresses[addr].v6 != '-':
                        yield dict(cmd, **{ "%saddr" % which_one : all_addresses[addr].v6 })
            return _filter_addr

        def service(service, which_one):
            def _filter_service(cmd):
                if service == "ALL":
                    yield cmd
                else:
                    if all_services[service].tcp != '-':
                        yield dict(cmd, proto="tcp", **{
                            "%sservice" % which_one : all_services[service].tcp,
                        })
                    if all_services[service].udp != '-':
                        yield dict(cmd, proto="udp", **{
                            "%sservice" % which_one : all_services[service].udp,
                        })
            return _filter_service

        def render_cmd(cmd):
            # What to do here depends on whether or not we're talking about a Docker service.
            if cmd["intaddr"] != "DOCKER":
                # Non-Docker. We need to configure PREROUTING with a DNAT rule, and allow that
                # traffic through FORWARD.
                fmt_dnat = "%(cmd)s -t 'nat'    -A 'MFWPREROUTING' -i '%(iface)s' -d '%(extaddr)s' "
                fmt_fltr = "%(cmd)s -t 'filter' -A 'MFWFORWARD'    -i '%(iface)s' -d '%(intaddr)s' "

                if cmd.get("extservice"):
                    fmt_dnat += "-p '%(proto)s' -m '%(proto)s' --dport '%(extservice)s' "
                    fmt_fltr += "-p '%(proto)s' -m '%(proto)s' --dport '%(intservice)s' "

                    cmd["extservice"] = cmd["extservice"].replace("-", ":")
                    cmd["intservice"] = cmd["intservice"].replace("-", ":")

                if virtual.intservice == virtual.extservice:
                    fmt_dnat += "-j DNAT --to-destination '%(intaddr)s'"
                    fmt_fltr += "-j ACCEPT"
                else:
                    fmt_dnat += "-j DNAT --to-destination '%(intaddr)s:%(intservice)s'"
                    fmt_fltr += "-j ACCEPT"

                yield fmt_dnat % cmd
                yield fmt_fltr % cmd

            else:
                # Docker. PREROUTING's gonna be handled by Docker, but Docker _also_ spawns a
                # docker-proxy on the host, which is reachable through INPUT. Thus:
                # * PREROUTING: Nothing to do, Docker handles that
                # * FORWARD needs to allow traffic to intservice on Docker networks. Docker
                #   will create container-specific rules in the DOCKER chain, so we just RETURN.
                # * INPUT needs to allow traffic to extservice (where docker-proxy listens).
                for interface in all_interfaces:
                    if interface.zone == "DOCKER":
                        fmt_fltr = (
                            "%(cmd)s -A 'MFWFORWARD' -i '%(iface)s' -o '%(dstiface)s' "
                            "-p '%(proto)s' -m '%(proto)s' --dport '%(intservice)s' "
                            "-j RETURN"
                        )
                        yield fmt_fltr % dict(cmd, dstiface=interface.name)

                fmt_inpt = (
                    "%(cmd)s -A 'MFWINPUT' -i '%(iface)s' "
                    "-p '%(proto)s' -m '%(proto)s' --dport '%(extservice)s' "
                    "-j ACCEPT"
                )
                yield fmt_inpt % cmd

        pipeline = [
            iptables(),
            interfaces,
            address(virtual.extaddr,    "ext"),
            address(virtual.intaddr,    "int"),
            service(virtual.extservice, "ext"),
            service(virtual.intservice, "int"),
            render_cmd
        ]

        # Now reduce() the pipeline to generate the actual commands.
        for command in reduce(chain_gen, pipeline):
            printf(command)

    # Accept icmp by default, unless a previous rule explicitly rejected/dropped it

    printf("iptables  -A MFWINPUT   -p icmp -j ACCEPT")
    printf("iptables  -A MFWFORWARD -p icmp -j ACCEPT")

    printf("ip6tables -A MFWINPUT   -p icmpv6 -j ACCEPT")
    printf("ip6tables -A MFWFORWARD -p icmpv6 -j ACCEPT")

    # Generate last-resort reject rules

    printf("iptables  -A MFWINPUT   -j reject")
    printf("ip6tables -A MFWINPUT   -j reject")
    printf("iptables  -A MFWFORWARD -j reject")
    printf("ip6tables -A MFWFORWARD -j reject")

    printf("")

    # Now determine where to plug into. If docker is present on this system
    # (as indicated by a DOCKER zone existing), plug into DOCKER-USER; otherwise
    # plug directly into FORWARD.
    # Since Docker completely ignores IPv6, attach to FORWARD there regardless.
    if "DOCKER" in all_zones:
        printf("iptables  -t filter -I DOCKER-USER -j MFWFORWARD")
    else:
        printf("iptables  -t filter -I FORWARD     -j MFWFORWARD")

    printf("ip6tables -t filter -I FORWARD     -j MFWFORWARD")
    printf("iptables  -t filter -I INPUT       -j MFWINPUT")
    printf("ip6tables -t filter -I INPUT       -j MFWINPUT")
    printf("iptables  -t nat    -I PREROUTING  -j MFWPREROUTING")
    printf("ip6tables -t nat    -I PREROUTING  -j MFWPREROUTING")
    printf("iptables  -t nat    -I POSTROUTING -j MFWPOSTROUTING")
    printf("ip6tables -t nat    -I POSTROUTING -j MFWPOSTROUTING")

    if use_mangle:
        printf("iptables  -t mangle -I FORWARD     -j MFWFORWARD")
        printf("ip6tables -t mangle -I FORWARD     -j MFWFORWARD")

    return output

if __name__ == '__main__':
    tables = Tables(
        read_table("addresses"),
        read_table("services"),
        read_table("interfaces"),
        read_table("rules"),
        read_table("virtuals")
    )

    rules = generate_setup(tables)

    print("#!/bin/bash")
    print("set +e")
    print("set -u")
    print("")
    print("\n".join(rules))
