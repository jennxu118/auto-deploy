"""
A collection of specialized objects and functions to perform ad hoc tasks. These methods are also available in Python
expressions in application DAG configuration YAML or JSON files.
"""
from pathlib import Path
import yaml
import json


def get_project_root() -> Path:
    """Returns the path to the project root folder.

    Returns:
        Project's root path

    """

    return Path(__file__).parent.parent


def get_full_path(relative_path: str) -> Path:
    """Returns the full path from the project root folder to the supplied relative path.

    Returns:
        Supplied relative path as a full path

    """

    return get_project_root().joinpath(relative_path)


def get_file(path, file_type = "yaml"):
    path = str(get_full_path(path))
    with open(path) as f:
        if file_type == "yaml":
            data = yaml.load(f, Loader = yaml.FullLoader)
            return data
        elif file_type == "json":
            data = json.load(f)
            return data
        else:
            raise Exception("Unknown file type!!")
