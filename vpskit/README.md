# VPSKit Backend

VPSKit is a production control plane for PayPal-backed VPS provisioning.

## What is included

- Typed environment settings in `vpskit.config`
- A FastAPI app with health, dashboard, user, and webhook routes
- Postgres-backed order/subscription/job persistence
- Redis stream job delivery for the provisioning worker
- Subscription profile models and a compact text renderer

## Local development

```bash
python3.11 -m venv .venv
source .venv/bin/activate
pip install -e ".[dev]"
pytest tests/ -v
uvicorn vpskit.main:app --reload
```

## Systemd deployment

The production installer lives at [`scripts/install_systemd.sh`](../scripts/install_systemd.sh).

It copies the project to `/opt/vpskit`, creates `/opt/vpskit/venv`, installs the
package, registers these services, and enables boot persistence:

- `vpskit-api.service`
- `vpskit-worker.service`

Required environment file:

- `/etc/vpskit.env`

Required variables:

- `DATABASE_URL`
- `REDIS_URL`
- `PAYPAL_CLIENT_ID`
- `PAYPAL_CLIENT_SECRET`
- `PAYPAL_WEBHOOK_ID`
- `PAYPAL_WEBHOOK_SECRET`
- `PAYPAL_ENV=live`
- `VPS_HOST`
- `VPS_USER`
- `VPS_SSH_PRIVATE_KEY`
- `VPSKIT_API_TOKEN`

`VPS_SSH_PRIVATE_KEY` is best treated as a path to a key file rather than a
multiline PEM blob, because `EnvironmentFile=` is line-oriented.

Commercial flow:

1. PayPal payment webhook arrives at `/webhook/paypal`
2. VPSKit validates the webhook signature
3. VPSKit creates or updates the user, order, subscription, and provisioning job in Postgres
4. VPSKit publishes the job to the Redis stream once
5. The systemd worker drains the queue and provisions the VPS
6. The worker marks the job `SUCCESS`, `FAILED`, or `DEAD`

`webhook/paypal` is idempotent by payment id. Duplicate delivery does not
create extra orders or jobs.

The worker and API logs are available in journald:

```bash
journalctl -u vpskit-api -f
journalctl -u vpskit-worker -f
```

## Environment

| Variable | Default | Purpose |
| --- | --- | --- |
| `VPSKIT_ENV` | `development` | Runtime environment label |
| `VPSKIT_HOST` | `0.0.0.0` | API bind host |
| `VPSKIT_PORT` | `8080` | API bind port |

Do not store secrets in source files. Put credentials in `.env` or the deployment environment.
