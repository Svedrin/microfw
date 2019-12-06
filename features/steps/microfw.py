# encoding: utf-8

import os.path
import sys

from io import StringIO
from behave import given, when, then

BASE_DIR = os.path.dirname(os.path.dirname(os.path.dirname(__file__)))
sys.path.append(os.path.join(BASE_DIR, "src"))
import generate_setup

@given("{tabletype} table from {directory}")
def step(context, tabletype, directory):
    if not hasattr(context, "tables"):
        context.tables = {}
    table_path = os.path.join(BASE_DIR, directory, tabletype)
    if not os.path.exists(table_path):
        raise ValueError("%s does not exist" % table_path)
    generate_setup.ETC_DIR = os.path.join(BASE_DIR, directory)
    context.tables[tabletype] = generate_setup.read_table(tabletype)

@then("the rules compile")
def step(context):
    tables = generate_setup.Tables(
        context.tables["addresses"],
        context.tables["services"],
        context.tables["interfaces"],
        context.tables["rules"],
        context.tables["virtuals"]
    )
    context.rules = generate_setup.generate_setup(tables)
