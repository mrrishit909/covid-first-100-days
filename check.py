"""Step 5: the project's check. Recompute with different code, in plain Python (the csv module, lists and loops: no R, pandas or numpy): the audit, every day of the world and of the world outside China,
the spread over the first 100 days, each country's day 0 and its growth over the next 14 days (a least-squares line through the logarithm of the cases, written out by hand), the groups by arrival
period with medians and quartiles, and a Spearman correlation with ties given their average rank.

    python3 check.py
"""
import csv
import datetime as dt
import math
from collections import defaultdict
from pathlib import Path

from scipy import stats

HERE = Path(__file__).parent
R = HERE / "results"
NON = {"Diamond Princess", "MS Zaandam", "Summer Olympics 2020", "Winter Olympics 2022"}
EPOCH = dt.date(1970, 1, 1)
n_ok = 0


def same(label, got, want, rel=1e-9):
    global n_ok
    n_ok += 1
    want = float(want) if want not in ("NA",) else float("nan")
    if math.isinf(want) or math.isnan(want):
        assert (math.isinf(got) and math.isinf(want) and got * want > 0) or (math.isnan(got) and math.isnan(want)), f"{label}: recount {got} != results {want}"
    else:
        assert abs(got - want) <= rel * max(1.0, abs(want)), f"{label}: recount {got} != results {want}"


def eq(label, got, want):
    global n_ok
    n_ok += 1
    assert got == want, f"{label}: recount {got!r} != results {want!r}"


def table(name):
    return list(csv.DictReader(open(R / f"{name}.csv")))


def quantile(v, q):                                  # R's default (type 7)
    v = sorted(v); pos = q * (len(v) - 1); lo = math.floor(pos)
    return v[lo] + (v[min(lo + 1, len(v) - 1)] - v[lo]) * (pos - lo)


def ranks(v):
    order = sorted(range(len(v)), key=lambda i: v[i]); r = [0.0] * len(v); i = 0
    while i < len(v):
        j = i
        while j + 1 < len(v) and v[order[j + 1]] == v[order[i]]:
            j += 1
        for k in range(i, j + 1):
            r[order[k]] = (i + j) / 2 + 1
        i = j + 1
    return r


def main():
    global n_ok
    rows = list(csv.reader(open(HERE / "data" / "time_series_covid19_confirmed_global.csv"))); head = rows[0]; body = rows[1:]
    dates = [dt.datetime.strptime(h, "%m/%d/%y").date() for h in head[4:]]; n = len(dates)
    assert dates == [dates[0] + dt.timedelta(days=k) for k in range(n)]
    missing = sum(1 for r in body for v in r[4:] if v.strip() == "")
    series = defaultdict(lambda: [0] * n); dropped_last = 0
    for r in body:
        vals = [int(float(v)) for v in r[4:]]
        if r[1] in NON:
            dropped_last += vals[-1]
        else:
            s = series[r[1]]
            for k, v in enumerate(vals):
                s[k] += v
    names = sorted(series)

    # audit
    a = {r["check"]: float(r["value"]) for r in table("audit")}
    falls = [(series[c][k] - series[c][k - 1], c, dates[k].isoformat()) for c in names for k in range(1, n) if series[c][k] < series[c][k - 1]]
    china = sorted((series["China"][k] - series["China"][k - 1] for k in range(1, 100)), reverse=True)
    for label, got in (("rows in the file", len(body)), ("country or region names", len({r[1] for r in body})), ("rows that are not countries", len(NON)), ("countries and territories", len(names)),
                       ("first date", (dates[0] - EPOCH).days), ("last date", (dates[-1] - EPOCH).days), ("days", n), ("missing case values", missing), ("cases on the last day in the four rows left out", dropped_last),
                       ("country-days where the cumulative count fell", len(falls)), ("countries where it fell at least once", len({f[1] for f in falls})), ("largest one-day fall", -min(falls)[0]),
                       ("China's largest one-day rise in its first 100 days", china[0]), ("China's second largest one-day rise in its first 100 days", china[1])):
        same(label, got, a[label])
    for r, f in zip(table("falls"), sorted(falls)[:5]):
        eq("fall country", r["country"], f[1]); eq("fall date", r["date"], f[2]); same("fall change", f[0], r["change"])
    eq("falls listed", len(table("falls")), 5)

    # the world and the world outside China
    world = [sum(series[c][k] for c in names) for k in range(n)]; outside = [world[k] - series["China"][k] for k in range(n)]
    def dbl(s, k):
        return 7 * math.log(2) / math.log(s[k] / s[k - 7]) if k >= 7 else float("nan")
    for r in table("world"):
        k = int(r["day"]) - 1; eq("world date", r["date"], dates[k].isoformat()); same(f"cumulative day {k + 1}", world[k], r["cumulative"])
        same("new", world[k] - world[k - 1] if k else float("nan"), r["new"]); same("doubling7", dbl(world, k), r["doubling7_days"])
        same("outside", outside[k], r["outside_china"]); same("outside doubling7", dbl(outside, k), r["outside_china_doubling7_days"])
    eq("world rows", len(table("world")), n)
    day_fast = min(range(7, 100), key=lambda k: dbl(world, k)); out_fast = min((k for k in range(7, 100) if outside[k] >= 1000), key=lambda k: dbl(outside, k))

    # spread
    def spread(k):
        v = [series[c][k] for c in names]; return sum(x >= 1 for x in v), sum(x >= 100 for x in v), sum(x >= 1000 for x in v)
    for tab in ("spread", "spread_daily"):
        for r in table(tab):
            k = int(r["day"]) - 1; eq(f"{tab} date", r["date"], dates[k].isoformat()); s = spread(k)
            same(f"{tab} {k + 1} >=1", s[0], r["at_least_1"]); same("100", s[1], r["at_least_100"]); same("1000", s[2], r["at_least_1000"])
    eq("spread_daily rows", len(table("spread_daily")), 100); eq("spread rows", [int(r["day"]) for r in table("spread")], [1, 25, 50, 75, 100])

    # each country after it passed 100 cases
    out, day0 = {}, {}
    for c in names:
        s = series[c]; idx = [k for k in range(n) if s[k] >= 100]
        if not idx:
            continue
        i0 = idx[0]; day0[c] = i0
        if i0 + 14 >= n:
            continue
        y = [math.log(s[i0 + j]) for j in range(15)]; x = list(range(15)); mx, my = 7.0, sum(y) / 15
        sxx = sum((u - mx) ** 2 for u in x); sxy = sum((u - mx) * (v - my) for u, v in zip(x, y)); syy = sum((v - my) ** 2 for v in y); b = sxy / sxx
        at = lambda j: s[i0 + j] if i0 + j < n else float("nan")
        out[c] = {"day0": dates[i0].isoformat(), "slope": b, "doubling": math.log(2) / b if b > 0 else float("inf"), "r2": sxy * sxy / (sxx * syy), "factor14": s[i0 + 14] / s[i0], "c30": at(30), "c60": at(60), "c100": at(100)}
    rows_c = table("countries"); eq("countries listed", sorted(r["country"] for r in rows_c), sorted(out)); eq("sorted by doubling", [r["country"] for r in rows_c], [c for c, _ in sorted(out.items(), key=lambda kv: (kv[1]["doubling"], kv[0]))])
    for r in rows_c:
        o = out[r["country"]]; eq(f"day0 {r['country']}", r["day0"], o["day0"])
        for key in ("slope", "doubling", "r2", "factor14", "c30", "c60", "c100"):
            same(f"{key} {r['country']}", o[key], r[key], 1e-8)

    # by arrival period, and the summary
    edges = [("to Feb 2020", "0000-00-00", "2020-03-01"), ("Mar 2020", "2020-03-01", "2020-04-01"), ("Apr 2020", "2020-04-01", "2020-05-01"), ("May-Jun 2020", "2020-05-01", "2020-07-01"),
             ("Jul-Dec 2020", "2020-07-01", "2021-01-01"), ("2021 or later", "2021-01-01", "9999-99-99")]
    for r, (label, lo, hi) in zip(table("by_period"), edges):
        v = [o["doubling"] for o in out.values() if lo <= o["day0"] < hi and math.isfinite(o["doubling"])]
        eq("period", r["period"], label); same(f"{label} n", len(v), r["countries"]); same("median", quantile(v, 0.5), r["median_doubling"], 1e-8); same("q1", quantile(v, 0.25), r["q1"], 1e-8); same("q3", quantile(v, 0.75), r["q3"], 1e-8)
    fin = [(dt.date.fromisoformat(o["day0"]) - EPOCH).days for o in out.values() if math.isfinite(o["doubling"])]; dv = [o["doubling"] for o in out.values() if math.isfinite(o["doubling"])]
    rx, ry = ranks(fin), ranks(dv); mx, my = sum(rx) / len(rx), sum(ry) / len(ry)
    rho = sum((u - mx) * (v - my) for u, v in zip(rx, ry)) / math.sqrt(sum((u - mx) ** 2 for u in rx) * sum((v - my) ** 2 for v in ry)); t = rho * math.sqrt((len(rx) - 2) / (1 - rho * rho)); pv = 2 * stats.t.sf(abs(t), len(rx) - 2)
    sm = {r["key"]: float(r["value"]) for r in table("summary")}
    exp = {"countries_and_territories": len(names), "reached_100": len(day0), "reached_100_within_first_100_days": sum(i <= 99 for i in day0.values()), "world_day_100_cases": world[99], "outside_china_day_100_cases": outside[99],
           "outside_china_share_day_25_pct": 100 * outside[24] / world[24], "outside_china_share_day_50_pct": 100 * outside[49] / world[49], "outside_china_share_day_100_pct": 100 * outside[99] / world[99],
           "world_fastest_doubling_days": dbl(world, day_fast), "world_fastest_doubling_day_number": day_fast + 1, "outside_china_fastest_doubling_days": dbl(outside, out_fast), "outside_china_fastest_doubling_day_number": out_fast + 1,
           "countries_with_15_days_after_100": len(out), "median_doubling_14d": quantile(dv, 0.5), "doubling_q1": quantile(dv, 0.25), "doubling_q3": quantile(dv, 0.75), "no_growth_countries": sum(not math.isfinite(o["doubling"]) for o in out.values()),
           "median_r2": quantile([o["r2"] for o in out.values()], 0.5), "share_r2_above_95_pct": 100 * sum(o["r2"] > 0.95 for o in out.values()) / len(out), "spearman_rho": rho, "spearman_n": len(rx)}
    eq("summary keys", sorted(sm), sorted(list(exp) + ["spearman_p"]))
    for k, v in exp.items():
        same(f"summary {k}", v, sm[k], 1e-8)
    assert math.isclose(pv, sm["spearman_p"], rel_tol=1e-6), f"spearman p: recount {pv} != results {sm['spearman_p']}"; n_ok += 1
    print(f"check.py: {n_ok} recomputed numbers agree with results/ (a least-squares line, quantiles and a tie-aware Spearman correlation written out by hand)")


if __name__ == "__main__":
    main()
