import re
from pathlib import Path

from setuptools import find_packages, setup

required = []

if Path("README.md").exists():
    with open("README.md") as f:
        readme = f.read()

if Path("requirements.txt").exists():
    with open("requirements.txt") as f:
        required = [
            re.sub(r"^(-e\s)(.*\#egg=)(.*)$", r"\g<3> @ \g<2>\g<3>", r)
            for r in f.read().splitlines()
        ][1:]

setup(
    name = "auto-deploy",
    version = "0.0.8",
    license = "proprietary",
    description = "",
    long_description = readme,
    long_description_content_type = "text/x-rst; charset=UTF-8",
    url = "https://github.com/jennxu118/auto-deploy",
    author = "jennifer",
    author_email = "",
    python_requires = ">=3.6",
    packages = find_packages(exclude = ["docs", "scripts", "tests*", "tools"]),
    install_requires = required,
    include_package_data = True,
)
