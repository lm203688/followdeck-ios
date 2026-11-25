#!/usr/bin/env python3
"""Submit the in-flight iOS App Store version to App Review via the ASC REST API.

Gated to the CI `release` action only. Uses the stored ASC API key (.p8) to mint an
ES256 JWT; no third-party Python crypto package is required. The DER ECDSA signature
produced by `openssl dgst -sign` is converted to the raw R||S encoding required by an
ES256 JWT.

Preconditions (completed in the ASC web first; see docs/signing-runbook.md section 8.1):
- an in-flight appStoreVersion exists with metadata, screenshots, review detail and contact;
- the uploaded build has finished processing and is associated to the version;
- any Pro subscription versions to review together are Ready to Submit.
"""

import base64
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request

API = "https://api.appstoreconnect.apple.com"
APP_ID = os.environ.get("ASC_APP_ID", "6838357401")
KEY_ID = os.environ["ASC_KEY_ID"]
ISSUER_ID = os.environ["ASC_ISSUER_ID"]
KEY_CONTENT = os.environ["ASC_KEY_CONTENT"]
WORK = os.environ.get("RUNNER_TEMP", "/tmp")

# States that still represent an unreleased, submittable version.
IN_FLIGHT_STATES = {
    "PREPARE_FOR_SUBMISSION",
    "READY_FOR_REVIEW",
    "DEVELOPER_REJECTED",
    "REJECTED",
    "INVALID_BINARY",
}
# A submission in one of these states can be reused instead of creating a duplicate.
OPEN_SUBMISSION_STATES = {"READY_FOR_REVIEW", "WAITING_FOR_REVIEW"}


def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def der_to_raw_es256(der: bytes) -> bytes:
    """Convert a DER ECDSA-Sig-Value to the 64-byte raw R||S ES256 JWT encoding."""
    if der[0] != 0x30:
        raise ValueError("signature is not a DER SEQUENCE")
    i = 1
    length = der[i]
    i += 1
    if length & 0x80:
        n = length & 0x7F
        length = int.from_bytes(der[i:i + n], "big")
        i += n

    def read_integer(pos: int):
        if der[pos] != 0x02:
            raise ValueError("expected INTEGER in signature")
        pos += 1
        ilen = der[pos]
        pos += 1
        if ilen & 0x80:
            n = ilen & 0x7F
            ilen = int.from_bytes(der[pos:pos + n], "big")
            pos += n
        value = int.from_bytes(der[pos:pos + ilen], "big")
        return value, pos + ilen

    r, i = read_integer(i)
    s, _ = read_integer(i)
    return r.to_bytes(32, "big") + s.to_bytes(32, "big")


def mint_jwt() -> str:
    header = {"alg": "ES256", "kid": KEY_ID, "typ": "JWT"}
    now = int(time.time())
    payload = {
        "iss": ISSUER_ID,
        "iat": now,
        "exp": now + 1200,
        "aud": "appstoreconnect-v1",
    }
    signing_input = (
        b64url(json.dumps(header, separators=(",", ":")).encode())
        + "."
        + b64url(json.dumps(payload, separators=(",", ":")).encode())
    )

    key_path = os.path.join(WORK, "AuthKey.p8")
    with open(key_path, "w", encoding="utf-8") as f:
        f.write(KEY_CONTENT.strip() + "\n")
    os.chmod(key_path, 0o600)

    input_path = os.path.join(WORK, "jwt_input.bin")
    sig_path = os.path.join(WORK, "sig.der")
    with open(input_path, "wb") as f:
        f.write(signing_input.encode())

    subprocess.run(
        ["openssl", "dgst", "-sha256", "-sign", key_path, "-out", sig_path, input_path],
        check=True,
        capture_output=True,
    )
    with open(sig_path, "rb") as f:
        raw = der_to_raw_es256(f.read())
    return signing_input + "." + b64url(raw)


def api(method: str, path: str, token: str, body=None):
    url = API + path
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(
        url,
        data=data,
        method=method,
        headers={
            "Authorization": f"Bearer {token}",
            "Accept": "application/json",
            "Content-Type": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            raw = resp.read().decode()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        detail = e.read().decode()[:500]
        raise SystemExit(f"ASC {method} {path} -> HTTP {e.code}: {detail}")


def pick_inflight_version(token: str) -> dict:
    res = api(
        "GET",
        f"/v1/apps/{APP_ID}/appStoreVersions?filter[platform]=IOS&limit=20",
        token,
    )
    for version in res.get("data", []):
        state = version["attributes"].get("appStoreState")
        if state in IN_FLIGHT_STATES:
            return version
    raise SystemExit(
        "No in-flight iOS appStoreVersion found. Complete the version metadata in ASC first."
    )


def open_submission(token: str) -> str:
    res = api("GET", f"/v1/apps/{APP_ID}/reviewSubmissions?limit=20", token)
    for submission in res.get("data", []):
        if submission["attributes"].get("state") in OPEN_SUBMISSION_STATES:
            sid = submission["id"]
            print(f"Reusing open review submission {sid} "
                  f"({submission['attributes'].get('state')})")
            return sid

    created = api("POST", "/v1/reviewSubmissions", token, {
        "data": {
            "type": "reviewSubmissions",
            "attributes": {"platform": "IOS"},
            "relationships": {"app": {"data": {"type": "apps", "id": APP_ID}}},
        }
    })
    sid = created["data"]["id"]
    print(f"Created review submission {sid}")
    return sid


def run_inspect(token: str) -> None:
    """Read-only ASC state dump: versions, builds, subscription groups/products.

    Used to verify the stored ASC API key can reach the official REST endpoint and to
    cross-check the live state before assembling the in-flight version. No write calls.
    """
    versions = api(
        "GET",
        f"/v1/apps/{APP_ID}/appStoreVersions?filter[platform]=IOS&limit=20",
        token,
    )
    print("== App Store versions ==")
    for v in versions.get("data", []):
        a = v["attributes"]
        print(f"  {a.get('versionString')}  state={a.get('appStoreState')}  "
              f"releaseType={a.get('releaseType')}  id={v['id']}")

    builds = api(
        "GET",
        f"/v1/apps/{APP_ID}/builds?limit=20",
        token,
    )
    print("== Builds ==")
    for b in builds.get("data", []):
        a = b["attributes"]
        print(f"  version={a.get('version')}  processing={a.get('processingState')}  "
              f"expired={a.get('expired')}  uploaded={a.get('uploadedDate')}  id={b['id']}")

    groups = api("GET", f"/v1/apps/{APP_ID}/subscriptionGroups?limit=20", token)
    print("== Subscription groups ==")
    for g in groups.get("data", []):
        ga = g["attributes"]
        gid = g["id"]
        print(f"  group {gid}  name={ga.get('referenceName')}")
        subs = api("GET", f"/v1/subscriptionGroups/{gid}/subscriptions?limit=20", token)
        for s in subs.get("data", []):
            sa = s["attributes"]
            print(f"    product={sa.get('productId')}  state={sa.get('state')}  "
                  f"submitWithNext={sa.get('submitWithNextAppStoreVersion')}  id={s['id']}")


def find_version(token: str, version_string: str):
    res = api(
        "GET",
        f"/v1/apps/{APP_ID}/appStoreVersions?filter[platform]=IOS&limit=20",
        token,
    )
    for version in res.get("data", []):
        if version["attributes"].get("versionString") == version_string:
            return version
    return None


def run_prepare(token: str) -> None:
    """Create the in-flight draft version (if missing) and associate the target VALID build.

    Idempotent: an existing version with the target version string is reused, never duplicated.
    This only assembles the draft; it does not fill localization/screenshots and does NOT submit
    for review. Targets come from env: TARGET_VERSION (default 1.1), TARGET_BUILD (default 4).
    """
    target_version = os.environ.get("TARGET_VERSION", "1.1")
    target_build = os.environ.get("TARGET_BUILD", "4")

    version = find_version(token, target_version)
    if version:
        version_id = version["id"]
        print(f"Reusing existing {target_version} version {version_id} "
              f"({version['attributes'].get('appStoreState')})")
    else:
        created = api("POST", "/v1/appStoreVersions", token, {
            "data": {
                "type": "appStoreVersions",
                "attributes": {
                    "versionString": target_version,
                    "platform": "IOS",
                    "releaseType": "AFTER_APPROVAL",
                },
                "relationships": {"app": {"data": {"type": "apps", "id": APP_ID}}},
            }
        })
        version_id = created["data"]["id"]
        print(f"Created {target_version} draft version {version_id}")

    builds = api("GET", f"/v1/apps/{APP_ID}/builds?limit=20", token)
    target = None
    for b in builds.get("data", []):
        a = b["attributes"]
        if a.get("version") == target_build and a.get("processingState") == "VALID":
            target = b
            break
    if not target:
        raise SystemExit(f"No VALID build version {target_build} found for association.")
    build_id = target["id"]
    print(f"Associating build {build_id} (version {target_build}) to version {version_id}")

    api("PATCH", f"/v1/appStoreVersions/{version_id}/relationships/build", token, {
        "data": {"type": "builds", "id": build_id}
    })
    print(f"Build {build_id} associated to version {version_id}. Draft remains unsubmitted.")


def main():
    token = mint_jwt()
    command = sys.argv[1] if len(sys.argv) > 1 else "submit"

    if command == "inspect":
        run_inspect(token)
        return

    if command == "prepare":
        run_prepare(token)
        return

    version = pick_inflight_version(token)
    version_id = version["id"]
    attrs = version["attributes"]
    print(f"Target version {attrs.get('versionString')} ({version_id}), "
          f"state {attrs.get('appStoreState')}")

    submission_id = open_submission(token)

    api("POST", "/v1/reviewSubmissionItems", token, {
        "data": {
            "type": "reviewSubmissionItems",
            "relationships": {
                "reviewSubmission": {
                    "data": {"type": "reviewSubmissions", "id": submission_id}
                },
                "appStoreVersion": {
                    "data": {"type": "appStoreVersions", "id": version_id}
                },
            },
        }
    })
    print(f"Attached version {version_id} to submission {submission_id}")

    api("PATCH", f"/v1/reviewSubmissions/{submission_id}", token, {
        "data": {
            "type": "reviewSubmissions",
            "id": submission_id,
            "attributes": {"submitted": True},
        }
    })
    print(f"Submitted review submission {submission_id} for review.")


if __name__ == "__main__":
    main()
