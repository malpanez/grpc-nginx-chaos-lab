#!/usr/bin/env python3
import argparse
import math
import re
from pathlib import Path
from typing import Iterable, List, Optional, Tuple

LOG_PATTERN = re.compile(r"status=(?P<status>\\d+).*?rt=(?P<rt>[\\d\\.]+).*?urt=(?P<urt>[\\d\\.\\-]+)")


def parse_line(line: str) -> Optional[Tuple[int, float, Optional[float]]]:
    match = LOG_PATTERN.search(line)
    if not match:
        return None
    status = int(match.group("status"))
    rt = float(match.group("rt"))
    urt_raw = match.group("urt")
    urt = float(urt_raw) if urt_raw and urt_raw != "-" else None
    return status, rt, urt


def percentile(data: List[float], pct: float) -> float:
    if not data:
        return 0.0
    data_sorted = sorted(data)
    k = (len(data_sorted) - 1) * (pct / 100.0)
    f = math.floor(k)
    c = math.ceil(k)
    if f == c:
        return data_sorted[int(k)]
    return data_sorted[int(f)] + (data_sorted[int(c)] - data_sorted[int(f)]) * (k - f)


def summarize(records: Iterable[Tuple[int, float, Optional[float]]]):
    rts: List[float] = []
    statuses: List[int] = []
    for status, rt, _ in records:
        statuses.append(status)
        rts.append(rt)

    total = len(statuses)
    if total == 0:
        return {
            "total": 0,
            "errors": 0,
            "error_pct": 0.0,
            "avg": 0.0,
            "p50": 0.0,
            "p90": 0.0,
            "p99": 0.0,
        }

    errors = sum(1 for s in statuses if s >= 500)
    return {
        "total": total,
        "errors": errors,
        "error_pct": (errors / total) * 100.0,
        "avg": sum(rts) / total if total else 0.0,
        "p50": percentile(rts, 50),
        "p90": percentile(rts, 90),
        "p99": percentile(rts, 99),
    }


def main():
    parser = argparse.ArgumentParser(description="Analyze NGINX logs in grpc_combined format.")
    parser.add_argument("logfile", type=Path, help="Path to NGINX access log file")
    parser.add_argument("--label", default="baseline", help="Scenario label for the report")
    args = parser.parse_args()

    lines = args.logfile.read_text().splitlines()
    parsed = [res for line in lines if (res := parse_line(line))]
    summary = summarize(parsed)

    print(f"=== {args.label} ===")
    print(f"Total requests : {summary['total']}")
    print(f"Errors (status>=500): {summary['errors']} ({summary['error_pct']:.2f} %)")
    print(f"rt avg : {summary['avg']:.4f} s")
    print(
        "rt p50 / p90 / p99 : "
        f"{summary['p50']:.4f} / {summary['p90']:.4f} / {summary['p99']:.4f} s"
    )


if __name__ == "__main__":
    main()
