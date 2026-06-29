from __future__ import annotations

import copy
import hashlib
import hmac
import json
import pickle
from dataclasses import dataclass
from typing import Any, Callable

from vpskit.platform import CloudControlPlane
from vpskit.provisioning import DistributedProvisioningWorker

from stress_support import RecordingExecutor, StressBroker, StressRepository


SECRET = "stress-secret"


@dataclass(frozen=True)
class StressResult:
    name: str
    passed: bool
    detail: str


def sign_payload(payload: dict[str, object]) -> tuple[dict[str, str], str]:
    body = json.dumps(payload, separators=(",", ":"), sort_keys=True)
    signature = hmac.new(SECRET.encode(), body.encode(), hashlib.sha256).hexdigest()
    return {"PayPal-Transmission-Sig": signature}, body


def sign_body(body: str) -> dict[str, str]:
    signature = hmac.new(SECRET.encode(), body.encode(), hashlib.sha256).hexdigest()
    return {"PayPal-Transmission-Sig": signature}


def build_control_plane() -> tuple[StressRepository, StressBroker, CloudControlPlane]:
    repository = StressRepository()
    broker = StressBroker()
    control_plane = CloudControlPlane(repository, broker, webhook_secret=SECRET)
    return repository, broker, control_plane


def webhook_route(control_plane: CloudControlPlane, body: str, headers: dict[str, str], source_ip: str = "203.0.113.10") -> tuple[int, str]:
    try:
        accepted = control_plane.handle_paypal_webhook(body.encode(), headers, source_ip=source_ip)
    except ValueError as exc:
        message = str(exc).lower()
        if "signature" in message:
            return 403, "invalid_signature"
        return 400, "invalid_json"
    except Exception:  # noqa: BLE001
        return 503, "temporary_unavailable"

    if not accepted:
        return 200, "ignored"

    return 202, "queued"


def with_control_plane(func: Callable[[CloudControlPlane, StressRepository, StressBroker], StressResult]) -> StressResult:
    repository, broker, control_plane = build_control_plane()
    return func(control_plane, repository, broker)


def run_webhook_stress() -> StressResult:
    def _scenario(client: CloudControlPlane, repository: StressRepository, broker: StressBroker) -> StressResult:
        payload = {
            "event_type": "PAYMENT.CAPTURE.COMPLETED",
            "id": "WH-123",
            "resource": {
                "id": "PAY-123",
                "subscription_id": "SUB-456",
                "amount": {"value": "49.00"},
                "plan": "pro",
                "node_hint": "us-west",
                "subscriber": {
                    "email_address": "user@example.com",
                    "payer_id": "PAYER-1",
                },
            },
        }
        headers, body = sign_payload(payload)
        statuses = [webhook_route(client, body, headers)[0] for _ in range(5)]
        expected = [202, 200, 200, 200, 200]
        if statuses != expected:
            return StressResult("webhook_stress", False, f"unexpected statuses: {statuses}")

        counts = (
            len(repository.orders),
            len(repository.subscriptions),
            len(repository.jobs),
            len(broker.published),
        )
        if counts != (1, 1, 1, 1):
            return StressResult("webhook_stress", False, f"unexpected counts: {counts}")

        return StressResult("webhook_stress", True, "duplicate webhook delivery collapsed to one order/subscription/job")

    return with_control_plane(_scenario)


def run_failure_injection() -> StressResult:
    def _scenario(client: CloudControlPlane, repository: StressRepository, broker: StressBroker) -> StressResult:
        malformed_status, _ = webhook_route(client, "{", sign_body("{"))
        if malformed_status != 400:
            return StressResult("failure_injection", False, f"malformed JSON returned {malformed_status}")

        missing_fields_payload = {
            "event_type": "PAYMENT.CAPTURE.COMPLETED",
            "resource": {
                "amount": {"value": "49.00"},
                "plan": "pro",
                "subscriber": {
                    "email_address": "user@example.com",
                    "payer_id": "PAYER-1",
                },
            },
        }
        headers, body = sign_payload(missing_fields_payload)
        missing_fields_status, _ = webhook_route(client, body, headers)
        if missing_fields_status != 400:
            return StressResult("failure_injection", False, f"missing fields returned {missing_fields_status}")

        if repository.orders or repository.subscriptions or repository.jobs or broker.published:
            return StressResult("failure_injection", False, "invalid payloads created state")

        return StressResult("failure_injection", True, "invalid input rejected safely without job creation")

    return with_control_plane(_scenario)


def _run_worker_once(repository: StressRepository, broker: StressBroker, executor: RecordingExecutor, worker_id: str) -> bool:
    worker = DistributedProvisioningWorker(
        repository=repository,
        broker=broker,
        executor=executor,  # type: ignore[arg-type]
        worker_id=worker_id,
    )
    return worker.process_next_message()


def run_job_duplication() -> StressResult:
    repository = StressRepository()
    broker = StressBroker()
    payload = {
        "event_type": "PAYMENT.CAPTURE.COMPLETED",
        "id": "WH-321",
        "resource": {
            "id": "PAY-321",
            "subscription_id": "SUB-654",
            "amount": {"value": "49.00"},
            "plan": "pro",
            "subscriber": {
                "email_address": "user@example.com",
                "payer_id": "PAYER-2",
            },
        },
    }
    capture = repository.create_payment_capture(payload)
    if capture is None:
        return StressResult("job_duplication", False, "initial capture was unexpectedly treated as duplicate")

    for _ in range(2):
        broker.publish_job(capture.job)

    executor = RecordingExecutor(repository)
    processed = _drain_worker(repository, broker, executor)
    if not processed:
        return StressResult("job_duplication", False, "worker did not process jobs")

    if len(executor.calls) != 1:
        return StressResult("job_duplication", False, f"provisioning executed {len(executor.calls)} times")

    if repository.get_job(capture.job.job_id).status != "SUCCESS":
        return StressResult("job_duplication", False, "job was not marked successful")

    return StressResult("job_duplication", True, "duplicate job message was ignored after first provisioning")


def run_provisioning_safety() -> StressResult:
    repository = StressRepository()
    broker = StressBroker()
    payload = {
        "event_type": "PAYMENT.CAPTURE.COMPLETED",
        "id": "WH-654",
        "resource": {
            "id": "PAY-654",
            "subscription_id": "SUB-777",
            "amount": {"value": "49.00"},
            "plan": "pro",
            "node_hint": "us-west",
            "subscriber": {
                "email_address": "user@example.com",
                "payer_id": "PAYER-3",
            },
        },
    }
    capture = repository.create_payment_capture(payload)
    if capture is None:
        return StressResult("provisioning_safety", False, "initial capture was unexpectedly treated as duplicate")

    broker.publish_job(capture.job)
    crash_executor = RecordingExecutor(repository, crash_on_call=True)
    worker = DistributedProvisioningWorker(repository=repository, broker=broker, executor=crash_executor, worker_id="worker-crash")
    worker.process_next_message()

    state_blob = pickle.dumps((repository, broker))
    recovered_repository, recovered_broker = pickle.loads(state_blob)
    retry_executor = RecordingExecutor(recovered_repository)
    worker = DistributedProvisioningWorker(
        repository=recovered_repository,
        broker=recovered_broker,
        executor=retry_executor,  # type: ignore[arg-type]
        worker_id="worker-retry",
    )
    worker.process_next_message()

    job = recovered_repository.get_job(capture.job.job_id)
    if job.status != "SUCCESS":
        return StressResult("provisioning_safety", False, f"job ended in {job.status}")
    if len(retry_executor.calls) != 1:
        return StressResult("provisioning_safety", False, f"retry provisioning executed {len(retry_executor.calls)} times")
    if recovered_repository.get_subscription(capture.job.subscription_id).config_text is None:
        return StressResult("provisioning_safety", False, "subscription config was not stored")
    return StressResult("provisioning_safety", True, "crash mid-run safely retried without duplicate provisioning")


def run_worker_restart() -> StressResult:
    repository = StressRepository()
    broker = StressBroker()
    payload = {
        "event_type": "PAYMENT.CAPTURE.COMPLETED",
        "id": "WH-111",
        "resource": {
            "id": "PAY-111",
            "subscription_id": "SUB-222",
            "amount": {"value": "49.00"},
            "plan": "pro",
            "node_hint": "us-west",
            "subscriber": {
                "email_address": "user@example.com",
                "payer_id": "PAYER-4",
            },
        },
    }
    capture = repository.create_payment_capture(payload)
    if capture is None:
        return StressResult("worker_restart", False, "initial capture was unexpectedly treated as duplicate")
    broker.publish_job(capture.job)

    crash_executor = RecordingExecutor(repository, crash_on_call=True)
    worker = DistributedProvisioningWorker(repository=repository, broker=broker, executor=crash_executor, worker_id="worker-before-restart")
    worker.process_next_message()

    saved = pickle.dumps((repository, broker))
    restored_repository, restored_broker = pickle.loads(saved)
    retry_executor = RecordingExecutor(restored_repository)
    worker = DistributedProvisioningWorker(
        repository=restored_repository,
        broker=restored_broker,
        executor=retry_executor,  # type: ignore[arg-type]
        worker_id="worker-after-restart",
    )
    worker.process_next_message()

    job = restored_repository.get_job(capture.job.job_id)
    if job.status != "SUCCESS":
        return StressResult("worker_restart", False, f"job ended in {job.status}")
    if len(retry_executor.calls) != 1:
        return StressResult("worker_restart", False, f"job was provisioned {len(retry_executor.calls)} times after restart")
    if restored_broker.acked != [("vpskit:jobs", "1-0")]:
        return StressResult("worker_restart", False, f"unexpected acknowledgements: {restored_broker.acked}")
    return StressResult("worker_restart", True, "worker restart resumed the queued job safely")


def run_system_restart() -> StressResult:
    repository = StressRepository()
    broker = StressBroker()
    payload = {
        "event_type": "PAYMENT.CAPTURE.COMPLETED",
        "id": "WH-222",
        "resource": {
            "id": "PAY-222",
            "subscription_id": "SUB-333",
            "amount": {"value": "49.00"},
            "plan": "pro",
            "node_hint": "us-west",
            "subscriber": {
                "email_address": "user@example.com",
                "payer_id": "PAYER-5",
            },
        },
    }
    capture = repository.create_payment_capture(payload)
    if capture is None:
        return StressResult("system_restart", False, "initial capture was unexpectedly treated as duplicate")
    broker.publish_job(capture.job)

    first_executor = RecordingExecutor(repository, crash_on_call=True)
    first_worker = DistributedProvisioningWorker(repository=repository, broker=broker, executor=first_executor, worker_id="worker-before-reboot")
    first_worker.process_next_message()

    api_copy = pickle.loads(pickle.dumps((repository, broker)))
    reboot_repository, reboot_broker = api_copy
    second_executor = RecordingExecutor(reboot_repository)
    second_worker = DistributedProvisioningWorker(
        repository=reboot_repository,
        broker=reboot_broker,
        executor=second_executor,  # type: ignore[arg-type]
        worker_id="worker-after-reboot",
    )
    second_worker.process_next_message()

    job = reboot_repository.get_job(capture.job.job_id)
    if job.status != "SUCCESS":
        return StressResult("system_restart", False, f"job ended in {job.status}")
    if len(reboot_repository.orders) != 1 or len(reboot_repository.subscriptions) != 1 or len(reboot_repository.jobs) != 1:
        return StressResult("system_restart", False, "state was not preserved across reboot simulation")
    if len(second_executor.calls) != 1:
        return StressResult("system_restart", False, f"duplicate provisioning detected: {second_executor.calls}")
    return StressResult("system_restart", True, "system restart recovered preserved state without duplicate execution")


def _drain_worker(repository: StressRepository, broker: StressBroker, executor: RecordingExecutor) -> bool:
    worker = DistributedProvisioningWorker(repository=repository, broker=broker, executor=executor, worker_id="worker-drain")
    processed = False
    while worker.process_next_message():
        processed = True
        if not broker.messages:
            break
    return processed


def print_result(result: StressResult) -> None:
    status = "PASS" if result.passed else "FAIL"
    print(f"{status} {result.name}: {result.detail}")


def run_category(name: str) -> StressResult:
    mapping = {
        "webhook_stress": run_webhook_stress,
        "failure_injection": run_failure_injection,
        "worker_restart": run_worker_restart,
        "job_duplication": run_job_duplication,
        "provisioning_safety": run_provisioning_safety,
        "system_restart": run_system_restart,
    }
    return mapping[name]()
