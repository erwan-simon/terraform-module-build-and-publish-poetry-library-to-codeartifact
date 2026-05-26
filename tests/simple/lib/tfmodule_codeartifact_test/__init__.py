import requests


def run() -> str:
    return f"hello from terraform-test using requests {requests.__version__}"
