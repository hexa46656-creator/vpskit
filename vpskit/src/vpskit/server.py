"""Production FastAPI server entrypoint for VPSKit."""

from __future__ import annotations

import logging

import uvicorn

from vpskit.config import AppSettings, DeploymentSettings
from vpskit.main import app


logger = logging.getLogger(__name__)


def main() -> None:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    )
    settings = AppSettings.from_env()
    deployment_settings = DeploymentSettings.from_env()
    missing_values = deployment_settings.missing_required_values()

    if missing_values:
        logger.warning(
            "Missing deployment environment variables: %s",
            ", ".join(missing_values),
        )

    logger.info("Starting VPSKit API server")
    uvicorn.run(app, host=settings.host, port=settings.port, log_level="info")


if __name__ == "__main__":
    main()
