import sys

def after_scenario(context, scenario):
    """
    If the scenario failed, write its rules to /tmp/iptables-rules.txt for inspection.
    Protip: If you're developing a test and want to see the current ruleset, match for
    a rule named "dummy" or "yolo" to provoke an error and get a rule dump.
    """
    if not sys.stdout.isatty():
        return

    if scenario.compute_status() == "failed":
        with open("/tmp/iptables-rules.txt", "w") as fd:
            fd.write("\n".join(context.rules))
        print("rules written to /tmp/iptables-rules.txt")

