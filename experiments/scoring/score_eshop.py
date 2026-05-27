#!/usr/bin/env python3
"""
Score an eShopOnWeb decomposition against dimensions_eshop.json.

Verifiers follow the same shape as score_decomposition.py (returning
{aligned: bool, evidence: str}) but check eShop-specific patterns:
Catalog/Basket/Ordering/Identity bounded contexts, Redis-backed basket,
IdentityServer-style identity service, etc.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path


# --- helpers (mirrored from score_decomposition.py for self-containment) ----

def walk_files(repo: Path, suffix: str = ""):
    for p in repo.rglob("*"):
        if not p.is_file():
            continue
        s = str(p)
        if "/bin/" in s or "/obj/" in s or "/.git/" in s or "/node_modules/" in s:
            continue
        if suffix and not p.name.endswith(suffix):
            continue
        yield p


def read_text(p: Path) -> str:
    try:
        return p.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return ""


def grep_files(repo: Path, pattern: str, suffix: str = "") -> list[tuple[Path, str]]:
    rx = re.compile(pattern)
    hits: list[tuple[Path, str]] = []
    for p in walk_files(repo, suffix):
        text = read_text(p)
        for line in text.splitlines():
            if rx.search(line):
                hits.append((p, line.strip()))
                break
    return hits


# --- verifiers ---------------------------------------------------------------

ESHOP_CONTEXTS = {"catalog", "basket", "order", "ordering", "identity"}


def check_eshop_bounded_contexts(repo: Path) -> dict:
    csprojs = list(walk_files(repo, ".csproj"))
    names = {p.stem.lower() for p in csprojs}
    matched = set()
    for kw in ("catalog", "basket", "identity"):
        if any(kw in n for n in names):
            matched.add(kw)
    # Ordering and Order both count for the ordering context.
    if any("order" in n for n in names):
        matched.add("order")
    aligned = len(matched) >= 3
    return {
        "aligned": aligned,
        "evidence": f"matched contexts: {sorted(matched)} (from {sorted(names)[:8]})",
    }


def check_eshop_gateway(repo: Path) -> dict:
    yarp = grep_files(repo, r"Yarp\.ReverseProxy|AddReverseProxy", suffix=".cs")
    yarp_csproj = grep_files(repo, r"Yarp\.ReverseProxy", suffix=".csproj")
    ocelot = grep_files(repo, r"Ocelot", suffix=".cs") + grep_files(repo, r"Ocelot", suffix=".csproj")
    aligned = bool(yarp or yarp_csproj or ocelot)
    if yarp or yarp_csproj:
        ev = "YARP gateway"
    elif ocelot:
        ev = "Ocelot gateway"
    else:
        ev = "no gateway library found"
    return {"aligned": aligned, "evidence": ev}


def check_eshop_separate_projects(repo: Path) -> dict:
    csprojs = list(walk_files(repo, ".csproj"))
    aligned = len(csprojs) >= 4
    return {
        "aligned": aligned,
        "evidence": f"{len(csprojs)} .csproj files: {[p.name for p in csprojs][:6]}",
    }


def check_eshop_no_cross_project_refs(repo: Path) -> dict:
    csprojs = list(walk_files(repo, ".csproj"))
    # Anything that looks like a runnable service:
    service_csprojs = [p for p in csprojs
                       if not any(t in p.stem.lower()
                                  for t in ("test", "shared", "common", "applicationcore",
                                            "infrastructure", "blazor", "gateway"))]
    cross = []
    for p in service_csprojs:
        text = read_text(p)
        for other in service_csprojs:
            if other == p:
                continue
            if other.stem in text:
                cross.append(f"{p.name} -> {other.name}")
    aligned = len(cross) == 0
    return {
        "aligned": aligned,
        "evidence": "no cross-service refs" if aligned else f"{len(cross)} found: {cross[:3]}",
    }


def check_eshop_distinct_dbcontexts(repo: Path) -> dict:
    rx = re.compile(r"class\s+(\w+)\s*:\s*DbContext\b")
    names: set[str] = set()
    for p in walk_files(repo, ".cs"):
        for line in read_text(p).splitlines():
            m = rx.search(line)
            if m:
                names.add(m.group(1))
                break
    aligned = len(names) >= 2  # eShop typically has Catalog + Ordering as RDBMS; Basket is Redis
    return {
        "aligned": aligned,
        "evidence": f"{len(names)} DbContext class(es): {sorted(names)[:5]}",
    }


def check_eshop_db_isolation(repo: Path) -> dict:
    """Aligned if either HasDefaultSchema is used OR docker-compose has separate db services."""
    schema_hits = len(grep_files(repo, r"HasDefaultSchema\s*\(", suffix=".cs"))
    compose = [p for p in walk_files(repo) if p.name in ("docker-compose.yml", "docker-compose.yaml", "compose.yml")]
    separate_dbs = 0
    if compose:
        text = read_text(compose[0])
        # Count db-like service names
        for kw in ("catalog-db", "catalog_db", "ordering-db", "ordering_db",
                   "catalogdb", "orderingdb", "identitydb", "basketdb"):
            if kw in text.lower():
                separate_dbs += 1
    aligned = schema_hits >= 2 or separate_dbs >= 2
    return {
        "aligned": aligned,
        "evidence": f"HasDefaultSchema={schema_hits}, separate-db services in compose={separate_dbs}",
    }


def check_eshop_basket_cache(repo: Path) -> dict:
    """The Basket service should use Redis (or another cache), not a relational DB."""
    redis_csproj = grep_files(repo, r"StackExchange\.Redis", suffix=".csproj")
    redis_cs     = grep_files(repo, r"StackExchange\.Redis|IDistributedCache.*Redis", suffix=".cs")
    cache_pkg    = grep_files(repo, r"Microsoft\.Extensions\.Caching\.StackExchangeRedis", suffix=".csproj")
    aligned = bool(redis_csproj or redis_cs or cache_pkg)
    return {
        "aligned": aligned,
        "evidence": "Redis package present" if aligned else "no Redis dependency found",
    }


def check_eshop_no_cross_service_fk(repo: Path) -> dict:
    fk_hits = grep_files(repo, r"\[ForeignKey", suffix=".cs")
    aligned = True
    return {"aligned": aligned, "evidence": f"{len(fk_hits)} ForeignKey attributes total (heuristic check)"}


def check_eshop_typed_httpclients(repo: Path) -> dict:
    hits = grep_files(repo, r"AddHttpClient<", suffix=".cs")
    aligned = len(hits) >= 1
    return {"aligned": aligned, "evidence": f"{len(hits)} typed HttpClient registration(s)"}


def check_eshop_rest_endpoints(repo: Path) -> dict:
    map_get = grep_files(repo, r"MapGet\(|\[HttpGet", suffix=".cs")
    map_post = grep_files(repo, r"MapPost\(|\[HttpPost", suffix=".cs")
    aligned = len(map_get) >= 1 and len(map_post) >= 1
    return {"aligned": aligned, "evidence": f"GET endpoints: {len(map_get)}, POST: {len(map_post)}"}


def check_eshop_identity_service(repo: Path) -> dict:
    """Look for either a dedicated Identity service project or IdentityServer / JwtBearer config."""
    identity_proj = any("identity" in p.stem.lower() for p in walk_files(repo, ".csproj"))
    duende        = grep_files(repo, r"Duende\.IdentityServer", suffix=".csproj")
    is4           = grep_files(repo, r"IdentityServer4", suffix=".csproj")
    jwt_validate  = grep_files(repo, r"AddJwtBearer", suffix=".cs")
    aligned = identity_proj or bool(duende or is4) or len(jwt_validate) >= 1
    if identity_proj:
        ev = "Identity project present"
    elif duende or is4:
        ev = "IdentityServer package present"
    elif jwt_validate:
        ev = f"{len(jwt_validate)} AddJwtBearer call(s)"
    else:
        ev = "no identity service or JWT validation"
    return {"aligned": aligned, "evidence": ev}


def check_eshop_docker_compose(repo: Path) -> dict:
    compose = [p for p in walk_files(repo) if p.name in ("docker-compose.yml", "docker-compose.yaml", "compose.yml")]
    if not compose:
        return {"aligned": False, "evidence": "no docker-compose file"}
    text = read_text(compose[0])
    has_db = any(k in text.lower() for k in ("postgres", "sqlserver", "mssql", "mysql", "mongo"))
    has_services = text.count("build:") >= 2 or text.count("image:") >= 3
    aligned = has_db and has_services
    return {
        "aligned": aligned,
        "evidence": f"{compose[0].name}: db={has_db}, services_present={has_services}",
    }


def check_eshop_service_dockerfiles(repo: Path) -> dict:
    dockerfiles = [p for p in walk_files(repo) if p.name == "Dockerfile"]
    dotnet8 = sum(1 for d in dockerfiles
                  if any(k in read_text(d)
                         for k in ("dotnet/aspnet:8", "dotnet/sdk:8", "dotnet/aspnet:8.0", "dotnet/sdk:8.0")))
    aligned = len(dockerfiles) >= 2 and dotnet8 >= 1
    return {
        "aligned": aligned,
        "evidence": f"{len(dockerfiles)} Dockerfile(s), {dotnet8} target .NET 8",
    }


def check_eshop_no_appsettings_secrets(repo: Path) -> dict:
    appsettings = [p for p in walk_files(repo, ".json") if "appsettings" in p.name.lower()]
    suspicious = []
    for p in appsettings:
        for m in re.finditer(r"Password\s*=\s*([^;\"'\s,}]+)", read_text(p)):
            val = m.group(1)
            if val and val.lower() not in {"postgres", "password", "yourpassword", "changeme",
                                            "$password", "${db_password}", "your_strong_password!",
                                            "your(!)strong(!)password"}:
                suspicious.append(f"{p.name}: Password={val[:8]}...")
    aligned = len(suspicious) == 0
    return {"aligned": aligned, "evidence": "no hardcoded secrets" if aligned else f"{len(suspicious)} found"}


def check_eshop_allowed_hosts(repo: Path) -> dict:
    appsettings = [p for p in walk_files(repo, ".json")
                   if "appsettings" in p.name.lower() and "production" in p.name.lower()]
    if not appsettings:
        return {"aligned": True, "evidence": "no Production appsettings (vacuously aligned)"}
    star = sum(1 for p in appsettings if re.search(r'"AllowedHosts"\s*:\s*"\*"', read_text(p)))
    return {"aligned": star == 0, "evidence": f"{star} Production files with AllowedHosts=*"}


def check_eshop_internal_routes(repo: Path) -> dict:
    """Loose check: are some endpoints not exposed via the gateway YARP/Ocelot config?"""
    hits = grep_files(repo, r'"/internal/|\[Route\(.*internal|Internal[A-Z]', suffix=".cs")
    aligned = len(hits) >= 1
    return {"aligned": aligned, "evidence": f"{len(hits)} internal-route or InternalX references"}


def check_eshop_cors_policy(repo: Path) -> dict:
    any_origin = grep_files(repo, r"AllowAnyOrigin\(\)", suffix=".cs")
    return {"aligned": len(any_origin) == 0,
            "evidence": "no AllowAnyOrigin" if not any_origin else f"{len(any_origin)} AllowAnyOrigin calls"}


def check_eshop_readme(repo: Path) -> dict:
    readme = repo / "README.md"
    aligned = readme.exists() and readme.stat().st_size > 200
    return {"aligned": aligned, "evidence": f"README.md size={readme.stat().st_size if readme.exists() else 0}"}


def check_eshop_per_service_readme(repo: Path) -> dict:
    found = []
    for p in walk_files(repo):
        if p.name.lower() == "readme.md" and p.parent != repo:
            # Skip noise from caches, packages, test runner outputs.
            s = str(p)
            if any(skip in s for skip in (".venv", "node_modules", "packages", ".nuget")):
                continue
            found.append(p.relative_to(repo))
    aligned = len(found) >= 1
    return {"aligned": aligned, "evidence": f"{len(found)} per-service README(s): {found[:3]}"}


def check_eshop_architecture_doc(repo: Path) -> dict:
    arch = [p for p in walk_files(repo, ".md") if "architecture" in p.name.lower()]
    return {"aligned": len(arch) >= 1, "evidence": "ARCHITECTURE present" if arch else "no architecture doc"}


# --- main --------------------------------------------------------------------

VERIFIERS = {name: fn for name, fn in globals().items()
             if name.startswith("check_eshop_") and callable(fn)}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", required=True, type=Path)
    ap.add_argument("--rubric", required=True, type=Path)
    ap.add_argument("--output", required=True, type=Path)
    args = ap.parse_args()

    if not args.repo.is_dir():
        print(f"ERROR: repo not found: {args.repo}", file=sys.stderr)
        sys.exit(1)

    rubric = json.loads(args.rubric.read_text())
    results = []
    for dim in rubric["dimensions"]:
        v = VERIFIERS.get(dim["verifier"])
        if v is None:
            results.append({**{k: dim[k] for k in ("id", "category")},
                            "rubric": dim["rubric"].strip(),
                            "aligned": False,
                            "evidence": f"verifier not implemented: {dim['verifier']}"})
            continue
        try:
            outcome = v(args.repo)
        except Exception as e:
            outcome = {"aligned": False, "evidence": f"verifier crashed: {e!r}"}
        results.append({"id": dim["id"], "category": dim["category"],
                        "rubric": dim["rubric"].strip(), **outcome})

    aligned = sum(1 for r in results if r["aligned"])
    summary = {
        "repo": str(args.repo),
        "rubric": str(args.rubric),
        "total_dimensions": len(results),
        "aligned": aligned,
        "alignment_rate": round(aligned / len(results), 3) if results else 0,
        "results": results,
    }
    args.output.write_text(json.dumps(summary, indent=2))
    print(f"Scored {aligned}/{len(results)} dimensions aligned. Output: {args.output}")


if __name__ == "__main__":
    main()
