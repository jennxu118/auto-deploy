from rh_dip_core.utils import load_config
from rh_dip_core.core import DagRunner


def handler(event, context):
    etl = DagRunner(
        etl_dag_config = "src/applications/image_trimmer/etl_dag_config.yaml",
        app_properties = "src/applications/image_trimmer/properties",
        event = event,
        context = context,
    )
    etl.run()


if __name__ == "__main__":
    _event = load_config("tests/kafka_test_input.json")
    handler(_event, None)

