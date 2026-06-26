# VPSKit Backend

VPSKit is a small Python API skeleton for VPS automation workflows.

## What is included

- Typed environment settings in `vpskit.config`
- A FastAPI app with health and service-status routes
- Runtime service status models
- Subscription profile models and a compact text renderer

## Local development

```bash
python3.11 -m venv .venv
source .venv/bin/activate
pip install -e ".[dev]"
pytest tests/ -v
uvicorn vpskit.main:app --reload
```

## Environment

| Variable | Default | Purpose |
| --- | --- | --- |
| `VPSKIT_ENV` | `development` | Runtime environment label |
| `VPSKIT_HOST` | `0.0.0.0` | API bind host |
| `VPSKIT_PORT` | `8080` | API bind port |

Do not store secrets in source files. Put credentials in `.env` or the deployment environment.
