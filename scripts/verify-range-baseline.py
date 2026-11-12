#!/usr/bin/env python3
"""Verify a VibeRange foundation or complete deployment without printing secrets."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shlex
import subprocess
import sys
import time
from typing import Any, Callable


class CheckRunner:
    def __init__(self) -> None:
        self.results: list[dict[str, Any]] = []

    def check(self, name: str, operation: Callable[[], tuple[bool, str]]) -> None:
        try:
            passed, detail = operation()
        except Exception as exc:  # keep the remaining checks actionable
            passed, detail = False, str(exc)
        self.results.append({"name": name, "passed": passed, "detail": detail})

    @property
    def passed(self) -> bool:
        return all(item["passed"] for item in self.results)


def run(command: list[str], *, input_text: str | None = None, timeout: int = 60) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command,
        input=input_text,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=timeout,
        check=False,
    )


def require_success(result: subprocess.CompletedProcess[str], description: str) -> str:
    if result.returncode != 0:
        message = result.stderr.strip().splitlines()[-1:] or [f"exit {result.returncode}"]
        raise RuntimeError(f"{description}: {message[0]}")
    return result.stdout


class Verifier:
    def __init__(self, args: argparse.Namespace) -> None:
        self.args = args
        self.ssh_base = [
            "ssh",
            "-i",
            str(Path(args.jump_identity).expanduser()),
            "-o",
            "IdentitiesOnly=yes",
            "-o",
            "BatchMode=yes",
            "-o",
            "ConnectTimeout=10",
            args.jump_host,
        ]
        self.vms: dict[str, dict[str, Any]] = {}

    def ludus(self, *arguments: str, timeout: int = 60) -> str:
        command = shlex.split(self.args.ludus_command) + ["-r", self.args.range, *arguments]
        return require_success(run(command, timeout=timeout), "Ludus command failed")

    def jump(self, shell_command: str, timeout: int = 30) -> str:
        return require_success(run([*self.ssh_base, shell_command], timeout=timeout), "jump-host probe failed")

    def guest(self, role: str, shell_command: str, timeout: int = 40) -> str:
        if role == "attacker":
            user = "kali"
            password = os.environ.get("VIBERANGE_KALI_PASSWORD", "")
        else:
            user = "debian"
            password = os.environ.get("VIBERANGE_DEBIAN_PASSWORD", "")
        if not password:
            raise RuntimeError(
                f"deep checks require {'VIBERANGE_KALI_PASSWORD' if role == 'attacker' else 'VIBERANGE_DEBIAN_PASSWORD'}"
            )
        ip = self.vms[role]["ip"]
        remote_script = """
set -euo pipefail
user=$1
ip=$2
command=$3
IFS= read -r SSHPASS
export SSHPASS
exec timeout 30 sshpass -e ssh \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o LogLevel=ERROR \
  -o ConnectTimeout=8 \
  "$user@$ip" "$command"
""".strip()
        remote_command = "bash -c {} -- {} {} {}".format(
            shlex.quote(remote_script),
            shlex.quote(user),
            shlex.quote(ip),
            shlex.quote(shell_command),
        )
        return require_success(
            run([*self.ssh_base, remote_command], input_text=password + "\n", timeout=timeout),
            f"guest check failed for {role}",
        )

    def load_status(self) -> dict[str, Any]:
        status = json.loads(self.ludus("range", "list", "--json"))
        suffixes = {
            "router": "-router-debian12-x64",
            "analysis": "-clickhouse-ir",
            "attacker": "-attacker",
            "victim": "-k3s-vuln",
        }
        for role, suffix in suffixes.items():
            matches = [vm for vm in status.get("VMs", []) if vm.get("name", "").endswith(suffix)]
            if len(matches) != 1:
                raise RuntimeError(f"expected one {role} VM ending in {suffix!r}, found {len(matches)}")
            self.vms[role] = matches[0]
        return status

    def tcp(self, role: str, port: int) -> tuple[bool, str]:
        ip = self.vms[role]["ip"]
        deadline = time.monotonic() + self.args.service_wait
        while True:
            result = run([*self.ssh_base, f"timeout 8 nc -z {shlex.quote(ip)} {port}"], timeout=15)
            if result.returncode == 0:
                return True, f"{ip}:{port}"
            if time.monotonic() >= deadline:
                return False, f"{ip}:{port}"
            time.sleep(5)

    def http(self, name: str, url: str, expected: str = "") -> tuple[bool, str]:
        command = f"curl -fsSL --max-time 15 {shlex.quote(url)}"
        deadline = time.monotonic() + self.args.service_wait
        while True:
            result = run([*self.ssh_base, command], timeout=25)
            body = result.stdout.strip()
            passed = result.returncode == 0 and (not expected or expected in body)
            if passed:
                return True, name
            if time.monotonic() >= deadline:
                detail = result.stderr.strip().splitlines()[-1] if result.stderr.strip() else name
                return False, detail
            time.sleep(5)

    def telemetry_sources(self) -> tuple[bool, str]:
        analysis_ip = self.vms["analysis"]["ip"]
        expected = {"vector_internal", "linux_auditd", "kubernetes_audit", "container_log"}
        query = (
            "SELECT source_type, count() AS events FROM ir.raw_events "
            f"WHERE range_id = '{self.args.range}' GROUP BY source_type FORMAT JSON"
        )
        command = (
            f"curl -fsSG --max-time 15 --data-urlencode {shlex.quote('query=' + query)} "
            f"http://{shlex.quote(analysis_ip)}:8123"
        )
        deadline = time.monotonic() + self.args.service_wait
        observed: set[str] = set()
        while True:
            result = run([*self.ssh_base, command], timeout=25)
            if result.returncode == 0:
                try:
                    payload = json.loads(result.stdout)
                    observed = {str(row["source_type"]) for row in payload.get("data", []) if row.get("events", 0) > 0}
                except (json.JSONDecodeError, KeyError, TypeError):
                    observed = set()
            if expected <= observed:
                return True, ",".join(sorted(observed))
            if time.monotonic() >= deadline:
                missing = ",".join(sorted(expected - observed)) or "none"
                return False, f"missing={missing}; observed={','.join(sorted(observed)) or 'none'}"
            time.sleep(5)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--range", required=True, help="Ludus range ID")
    parser.add_argument("--profile", choices=("foundation", "complete"), default="complete")
    parser.add_argument("--ludus-command", default="ludus")
    parser.add_argument("--jump-host", required=True, help="SSH user@host with guest-network reachability")
    parser.add_argument("--jump-identity", required=True, help="path to the jump-host SSH private key")
    parser.add_argument("--deep", action="store_true", help="check guest systemd units and policy from inside VMs")
    parser.add_argument(
        "--service-wait",
        type=int,
        default=180,
        help="seconds to wait for each expected network service to become ready (default: 180)",
    )
    parser.add_argument("--json", action="store_true", dest="json_output")
    args = parser.parse_args()

    checks = CheckRunner()
    verifier = Verifier(args)

    try:
        status = verifier.load_status()
    except Exception as exc:
        checks.results.append({"name": "range inventory", "passed": False, "detail": str(exc)})
        status = {}

    checks.check(
        "range state SUCCESS",
        lambda: (status.get("rangeState") == "SUCCESS", str(status.get("rangeState", "missing"))),
    )
    checks.check(
        "testing disabled",
        lambda: (status.get("testingEnabled") is False, str(status.get("testingEnabled", "missing"))),
    )

    if verifier.vms:
        for role in ("router", "analysis", "attacker", "victim"):
            vm = verifier.vms[role]
            checks.check(
                f"{role} powered on",
                lambda vm=vm: (vm.get("poweredOn") is True, vm.get("name", "missing")),
            )
            checks.check(f"{role} SSH reachable", lambda role=role: verifier.tcp(role, 22))

        if args.profile == "complete":
            analysis_ip = verifier.vms["analysis"]["ip"]
            attacker_ip = verifier.vms["attacker"]["ip"]
            victim_ip = verifier.vms["victim"]["ip"]
            checks.check(
                "ClickHouse HTTP health",
                lambda: verifier.http("ClickHouse /ping", f"http://{analysis_ip}:8123/ping", "Ok"),
            )
            checks.check(
                "ClickHouse IR schema",
                lambda: verifier.http(
                    "ClickHouse IR native tables",
                    f"http://{analysis_ip}:8123/?query=SHOW%20TABLES%20FROM%20ir",
                    "linux_auditd",
                ),
            )
            checks.check("central Vector ingress", lambda: verifier.tcp("analysis", 6000))
            checks.check(
                "central Vector metrics",
                lambda: verifier.http("Vector metrics", f"http://{analysis_ip}:9598/metrics", "vector_"),
            )
            checks.check("Vector-native telemetry sources", verifier.telemetry_sources)
            checks.check("Caldera HTTP", lambda: verifier.http("Caldera", f"http://{attacker_ip}:8888/"))
            checks.check("k3s API reachable", lambda: verifier.tcp("victim", 6443))
            for port in range(1230, 1237):
                checks.check(f"Kubernetes Goat port {port}", lambda port=port: verifier.tcp("victim", port))

        if args.deep:
            for role in ("analysis", "attacker", "victim"):
                checks.check(
                    f"{role} foundation marker",
                    lambda role=role: (
                        bool(verifier.guest(role, "test -s /etc/viberange-foundation && echo present").strip()),
                        "/etc/viberange-foundation",
                    ),
                )

            if args.profile == "complete":
                deep_commands = {
                    "analysis": (
                        "systemctl is-active clickhouse-server.service vector.service "
                        "viberange-detection-receiver.service "
                        "viberange-detection-runner.service >/dev/null && "
                        "curl -fsS http://127.0.0.1:9100/healthz >/dev/null"
                    ),
                    "attacker": (
                        "systemctl is-active caldera.service vector.service caldera-agent.service >/dev/null && "
                        "curl -fsS http://127.0.0.1:8888/ >/dev/null"
                    ),
                    "victim": (
                        "systemctl is-active k3s.service kubernetes-goat-access.service "
                        "auditd.service vector.service >/dev/null"
                    ),
                }
                for role, command in deep_commands.items():
                    checks.check(
                        f"{role} expected services active",
                        lambda role=role, command=command: (
                            verifier.guest(role, command) is not None,
                            "systemd and local health checks",
                        ),
                    )

                policy_checks = (
                    ("attacker", "victim", 22, True),
                    ("attacker", "analysis", 22, False),
                    ("analysis", "victim", 22, False),
                    ("victim", "attacker", 22, False),
                )
                for source, target, port, expected in policy_checks:
                    target_ip = verifier.vms[target]["ip"]
                    command = f"timeout 6 bash -c '</dev/tcp/{target_ip}/{port}'"

                    def policy_check(
                        source: str = source,
                        command: str = command,
                        expected: bool = expected,
                        target: str = target,
                        port: int = port,
                    ) -> tuple[bool, str]:
                        result = run_guest_result(verifier, source, command)
                        observed = result
                        return observed == expected, f"{source}->{target}:{port} observed={'allow' if observed else 'deny'}"

                    checks.check(
                        f"policy {source} to {target}:{port} {'allow' if expected else 'deny'}",
                        policy_check,
                    )

    if args.json_output:
        print(json.dumps({"range": args.range, "profile": args.profile, "passed": checks.passed, "checks": checks.results}, indent=2))
    else:
        for item in checks.results:
            print(f"{'PASS' if item['passed'] else 'FAIL'}  {item['name']}: {item['detail']}")
        print(f"\n{'PASS' if checks.passed else 'FAIL'}: {sum(i['passed'] for i in checks.results)}/{len(checks.results)} checks")
    return 0 if checks.passed else 1


def run_guest_result(verifier: Verifier, role: str, command: str) -> bool:
    try:
        verifier.guest(role, command)
        return True
    except RuntimeError:
        return False


if __name__ == "__main__":
    sys.exit(main())
