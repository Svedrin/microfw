# encoding: utf-8

import re
import os.path
import sys

from io import StringIO
from behave import given, when, then

BASE_DIR = os.path.dirname(os.path.dirname(os.path.dirname(__file__)))
sys.path.append(os.path.join(BASE_DIR, "src"))
import generate_setup

@given("{tabletype} table of")
def step(context, tabletype):
    if not hasattr(context, "tables"):
        context.tables = {}
    context.tables[tabletype] = generate_setup.parse_table(
        filename = tabletype,
        table    = StringIO(context.text.strip())
    )

@given("{tabletype} table from {directory}")
def step(context, tabletype, directory):
    if not hasattr(context, "tables"):
        context.tables = {}
    table_path = os.path.join(BASE_DIR, directory, tabletype)
    if not os.path.exists(table_path):
        raise ValueError("%s does not exist" % table_path)
    generate_setup.ETC_DIR = os.path.join(BASE_DIR, directory)
    context.tables[tabletype] = generate_setup.read_table(tabletype)

@given("{tabletype} table is empty")
def step(context, tabletype):
    if not hasattr(context, "tables"):
        context.tables = {}
    context.tables[tabletype] = generate_setup.parse_table(
        filename = tabletype,
        table    = StringIO("")
    )

@then("the rules compile")
def step(context):
    tables = generate_setup.Tables(
        context.tables["addresses"],
        context.tables["services"],
        context.tables["interfaces"],
        context.tables["rules"],
        context.tables["virtuals"]
    )
    context.rules = [
        # replace multiple spaces with a single space to have whitespace changes not matter
        re.sub(' +', ' ', rule)
        for rule in generate_setup.generate_setup(tables)
    ]

@then("rule compilation raises a ValueError")
def step(context):
    tables = generate_setup.Tables(
        context.tables["addresses"],
        context.tables["services"],
        context.tables["interfaces"],
        context.tables["rules"],
        context.tables["virtuals"]
    )
    try:
        context.rules = [
            # replace multiple spaces with a single space to have whitespace changes not matter
            re.sub(' +', ' ', rule)
            for rule in generate_setup.generate_setup(tables)
        ]
    except ValueError:
        return
    else:
        assert False, "expected ValueError, but didn't get one"

@then("these rules exist")
def step(context):
    # We want to find rules in context.rules exactly in the order in which they appear
    # in context.text. To make this happen, create a generator over context.rules that
    # we use in the inner for loop, but create it out here so that it does not reset
    # for each wanted_rule.
    actual_rule_gen = iter(context.rules)

    for wanted_rule in context.text.strip().split("\n"):
        # replace multiple spaces with a single space to have whitespace changes not matter
        wanted_rule = re.sub(' +', ' ', wanted_rule)
        if not wanted_rule:
            continue
        # look for the wanted_rule in actual_rule_gen. If we find it, we're happy and we
        # continue. If we arrive at the end of the iterator, we raise an error.
        for actual_rule in actual_rule_gen:
            if actual_rule == wanted_rule:
                # Found it!
                # break so that the "else:" statement below does not execute, which
                # would raise an exception.
                # The outer for loop will then either continue, or be done.
                break
        else:
            raise ValueError("Rule is missing: '%s'" % wanted_rule)

@then("these rules do NOT exist")
def step(context):
    for rule in context.text.strip().split("\n"):
        # replace multiple spaces with a single space to have whitespace changes not matter
        rule = re.sub(' +', ' ', rule)
        if not rule:
            continue
        if rule in context.rules:
            raise ValueError("Rule should not exist: '%s'" % rule)
