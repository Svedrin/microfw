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

@then("these rules exist")
def step(context):
    for rule in context.text.strip().split("\n"):
        # replace multiple spaces with a single space to have whitespace changes not matter
        rule = re.sub(' +', ' ', rule)
        if rule not in context.rules:
            raise ValueError("Rule is missing: '%s'" % rule)
