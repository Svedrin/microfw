#!/usr/bin/env python3

import sys

from collections import defaultdict

def generate_teardown(iptables_dump, iptables="iptables"):
    output = []
    def printf(cmd):
        output.append("%s %s" % (iptables, cmd))

    table = None
    chains_in_table = defaultdict(list)

    for line in iptables_dump:
        line = line.strip()
        if line.startswith("#") or line == "COMMIT":
            continue
        elif line.startswith("*"):
            table = line[1:]
        elif line.startswith(":"):
            if table is None:
                raise ValueError("invalid dump, found chains but no table")
            chain, policy, stats = line[1:].split()
            chains_in_table[table].append(chain)
        else:
            # rule
            pass

    # Detach MFWPREROUTING, MFWINPUT and MFWFORWARD
    if "DOCKER-USER" in chains_in_table["filter"]:
        printf("-t filter -D DOCKER-USER -j MFWFORWARD")
    else:
        printf("-t filter -D FORWARD     -j MFWFORWARD")

    printf("-t filter -D INPUT       -j MFWINPUT")

    if "MFWFORWARD" in chains_in_table["mangle"]:
        printf("-t mangle -D FORWARD     -j MFWFORWARD")

    printf("-t nat    -D PREROUTING  -j MFWPREROUTING")
    printf("-t nat    -D POSTROUTING -j MFWPOSTROUTING")

    # Flush MFWPREROUTING, MFWINPUT and MFWFORWARD so the child chains are free
    for chain in ("accept", "drop", "reject", "MFWINPUT", "MFWFORWARD"):
        printf("-t filter -F %s" % chain)

    if "MFWFORWARD" in chains_in_table["mangle"]:
        printf("-t mangle -F MFWFORWARD")

    for chain in ("MFWPREROUTING", "MFWPOSTROUTING"):
        printf("-t nat    -F %s" % chain)

    # Flush and drop zone chains
    for chain in chains_in_table["filter"]:
        if chain.endswith("_inp") or chain.endswith("_fwd"):
            printf("-t filter -F %s" % chain)
            printf("-t filter -X %s" % chain)

    # Drop MFWPREROUTING, MFWINPUT and MFWFORWARD
    for chain in ("accept", "drop", "reject", "MFWINPUT", "MFWFORWARD"):
        printf("-t filter -X %s" % chain)

    if "MFWFORWARD" in chains_in_table["mangle"]:
        printf("-t mangle -X MFWFORWARD")

    for chain in ("MFWPREROUTING", "MFWPOSTROUTING"):
        printf("-t nat    -X %s" % chain)

    return output


if __name__ == '__main__':
    rules = generate_teardown(sys.stdin)

    print("\n".join(rules) + "\n")

