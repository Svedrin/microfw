# MicroFW

iptables firewall inspired by [shorewall](http://www.shorewall.net).

At the current state, it's probably only useable if you have some experience with shorewall already.


# Configuration

MicroFW uses four tables to read configuration data from. Examples of those can be found in the `etc` subdirectory.

## Services

A list of services (ssh, http, https etc) and their TCP and UDP ports. You can probably use this one as-is.

## Addresses

A list of address objects you want your firewall to know. You'll have to add your own entries here.

It is not possible to use plain IP addresses in the rules file. If you want your rules to target specific IP addresses or ranges, add them here.

## Interfaces

A list of interfaces, and which zone they belong to. (Note that unlike shorewall, MicroFW does not require a separate zones definition.)

## Rules

Here's where things get interesting: The rules file defines which traffic to allow or reject. This is basically a mixture of shorewall's
`rules` and `policy` files.


# Usage

Currently, it writes a bash script to stdout that you can load from `/etc/rc.local` or something in order to bring up your firewall.
