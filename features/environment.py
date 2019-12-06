import sys

def after_scenario(context, scenario):
    if not sys.stdout.isatty():
        return

    if scenario.compute_status() == "failed":
        with open("/tmp/iptables-rules.txt", "w") as fd:
            fd.write("\n".join(context.rules))
        print("rules written to /tmp/iptables-rules.txt")

