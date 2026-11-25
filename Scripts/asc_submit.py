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
import hashlib
import json
import os
import struct
import subprocess
import sys
import time
import urllib.error
import urllib.request
import zipfile

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
# Subscription version states that may be added to a review submission.
SUB_VERSION_STATES = {
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
        detail = e.read().decode()[:1800]
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


def _safe_get(token: str, path: str):
    try:
        return api("GET", path, token), None
    except urllib.error.HTTPError as e:
        return None, e.code
    except SystemExit:
        return None, "exit"


def _inspect_version_assets(token: str, version_id: str) -> None:
    """Read-only snapshot of an in-flight version's screenshots and localizations."""
    locs = api(
        "GET",
        f"/v1/appStoreVersions/{version_id}/appStoreVersionLocalizations"
        "?limit=20&include=appScreenshotSets",
        token,
    )
    total_shots = 0
    for loc in locs.get("data", []):
        la = loc["attributes"]
        desc = (la.get("description") or "").strip()
        kw = (la.get("keywords") or "").strip()
        whats = (la.get("whatsNew") or "").strip()
        sets = (loc.get("relationships", {})
                .get("appScreenshotSets", {}).get("data", []))
        shot_count = 0
        for s in sets:
            set_res = api("GET", f"/v1/appScreenshotSets/{s['id']}?include=appScreenshots", token)
            shot_count += len(
                set_res["data"].get("relationships", {})
                .get("appScreenshots", {}).get("data", [])
            )
        total_shots += shot_count
        print(f"    locale={la.get('locale')}  desc={len(desc)}  "
              f"keywords={len(kw)}  whatsNew={len(whats)}  "
              f"screenshotSets={len(sets)}  screenshots={shot_count}")
    print(f"    total appScreenshots={total_shots}")


def run_inspect(token: str) -> None:
    """Read-only ASC state dump: versions, builds, subscription groups/products.

    Used to verify the stored ASC API key can reach the official REST endpoint and to
    cross-check the live state before assembling the in-flight version. No write calls.
    """
    versions = api(
        "GET",
        f"/v1/apps/{APP_ID}/appStoreVersions?filter[platform]=IOS&limit=20&include=build",
        token,
    )
    print("== App Store versions ==")
    for v in versions.get("data", []):
        a = v["attributes"]
        rel_build = (v.get("relationships", {}).get("build", {})
                     .get("data") or {})
        build_id = rel_build.get("id", "(none)")
        print(f"  {a.get('versionString')}  state={a.get('appStoreState')}  "
              f"releaseType={a.get('releaseType')}  build={build_id}  id={v['id']}")
        if a.get("appStoreState") in IN_FLIGHT_STATES:
            _inspect_version_assets(token, v["id"])

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
        gvers, gv_err = _safe_get(token, f"/v1/subscriptionGroups/{gid}/versions?limit=20")
        gv_data = gvers.get("data", []) if gvers else []
        print(f"    groupVersions={len(gv_data)}" + (f" ERR({gv_err})" if gv_err else ""))
        for gv in gv_data:
            gva = gv["attributes"]
            gloc, gloc_err = _safe_get(token, f"/v1/subscriptionGroupVersions/{gv['id']}/localizations?limit=20")
            gloc_names = [
                f"{l['attributes'].get('locale')}:{l['attributes'].get('name')}"
                for l in gloc.get("data", [])
            ] if gloc else f"ERR({gloc_err})"
            print(f"    groupVersion {gv['id'][:8]} state={gva.get('state')} "
                  f"localizations={len(gloc.get('data', [])) if gloc else 'ERR'} [{'; '.join(gloc_names)}]")
        subs = api("GET", f"/v1/subscriptionGroups/{gid}/subscriptions?limit=20", token)
        for s in subs.get("data", []):
            det = api("GET", f"/v1/subscriptions/{s['id']}", token)
            sa = det["data"]["attributes"]
            shot = _existing_review_screenshot(token, s["id"])
            shot_state = "(none)"
            if shot:
                shot_state = (shot.get("attributes") or {}) \
                    .get("assetDeliveryState", {}).get("state")
            vers = api("GET", f"/v1/subscriptions/{s['id']}/versions?limit=20", token)
            ver_states = ", ".join(
                f"{v['attributes'].get('state')}({v['id'][:8]})"
                for v in vers.get("data", [])
            ) or "(none)"
            note_len = len((sa.get("reviewNote") or "").strip())
            print(f"    product={sa.get('productId')}  state={sa.get('state')}  "
                  f"submitWithNext={sa.get('submitWithNextAppStoreVersion')}  "
                  f"reviewNote={note_len}  reviewScreenshot={shot_state}  "
                  f"versions=[{ver_states}]  id={s['id']}")
            for v in vers.get("data", []):
                _inspect_sub_version(token, v["id"], s["id"], sa.get("productId"))


def _inspect_sub_version(token: str, ver_id: str, sub_id: str, product_id: str) -> None:
    """Deep read a subscription version's review-blocking relations (read-only)."""

    def _get_url(url: str):
        try:
            return api("GET", url, token), None
        except urllib.error.HTTPError as e:
            return None, e.code
        except SystemExit:
            return None, "exit"

    loc, loc_err = _get_url(f"/v1/subscriptionVersions/{ver_id}/localizations")
    loc_info = []
    if loc:
        for l in loc.get("data", []):
            la = l["attributes"]
            loc_info.append(
                f"{la.get('locale')}:name={len((la.get('name') or '').strip())},"
                f"desc={len((la.get('description') or '').strip())}"
            )
    loc_n = len(loc.get("data", [])) if loc else f"ERR({loc_err})"

    img, _ = _get_url(f"/v1/subscriptionVersions/{ver_id}/images")
    if img and img.get("data"):
        img_state = (img["data"][0].get("attributes") or {}) \
            .get("assetDeliveryState", {}).get("state") or "present"
    else:
        img_state = "none"

    price, price_err = _get_url(f"/v1/subscriptions/{sub_id}/prices?limit=200")
    n_terr = len(price["data"]) if (price and price.get("data") is not None) else f"ERR({price_err})"

    us, _ = _get_url(
        f"/v1/subscriptions/{sub_id}/prices?filter[territory]=USA"
        "&include=subscriptionPricePoint,territory")
    if us and us.get("data"):
        p = us["data"][0]
        pa = p.get("attributes") or {}
        pp = (p.get("relationships", {})
              .get("subscriptionPricePoint", {}).get("data") or {})
        pp_id = pp.get("id", "(none)")
        cust = ""
        for i in us.get("included", []):
            if i.get("id") == pp_id:
                cust = (i.get("attributes") or {}).get("customerPrice", "")
        price_state = (f"USA plan={pa.get('planType')} preserved={pa.get('preserved')} "
                       f"point={pp_id} customerPrice={cust} (total {n_terr} territories)")
    else:
        price_state = f"USA price missing (total {n_terr})"

    offer, _ = _get_url(f"/v1/subscriptions/{sub_id}/introductoryOffers?limit=200")
    offer_state = "present" if (offer and offer.get("data")) else "none"

    ver, ver_err = _get_url(f"/v1/subscriptionVersions/{ver_id}")
    ver_attrs = {}
    if ver and ver.get("data"):
        ver_attrs = ver["data"].get("attributes") or {}

    print(f"      └ {product_id} localizations={loc_n} [{'; '.join(loc_info)}]  "
          f"price={price_state}  image={img_state}  introOffer={offer_state}")
    print(f"        version attrs: {json.dumps(ver_attrs, ensure_ascii=False)}"
          if ver_attrs else f"        version attrs: ERR({ver_err})")


def collect_submission_subscription_versions(token: str) -> list:
    """Return the in-flight subscription versions that should accompany this binary.

    Walks subscription groups → subscriptions → subscription versions and keeps the
    submittable draft/rejected versions. Read-only; no submission items are created here.
    """
    out = []
    groups = api("GET", f"/v1/apps/{APP_ID}/subscriptionGroups?limit=20", token)
    for g in groups.get("data", []):
        subs = api(
            "GET", f"/v1/subscriptionGroups/{g['id']}/subscriptions?limit=20", token
        )
        for s in subs.get("data", []):
            product_id = s["attributes"].get("productId")
            vers = api(
                "GET", f"/v1/subscriptions/{s['id']}/versions?limit=20", token
            )
            for v in vers.get("data", []):
                state = v["attributes"].get("state")
                if state in SUB_VERSION_STATES:
                    out.append({
                        "id": v["id"],
                        "productId": product_id,
                        "state": state,
                    })
    return out


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


# --- Subscription review screenshot attachment (attach-screenshots lane) ---

REPO = os.environ.get("GITHUB_REPOSITORY", "lm203688/followdeck-ios")
GH_TOKEN = os.environ.get("GITHUB_TOKEN", "")


def _raw_request(method: str, url: str, data=None, headers=None, expect_json=True):
    h = dict(headers or {})
    req = urllib.request.Request(url, data=data, method=method, headers=h)
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            raw = resp.read()
    except urllib.error.HTTPError as e:
        detail = e.read().decode()[:500]
        raise SystemExit(f"{method} {url} -> HTTP {e.code}: {detail}")
    if expect_json:
        return json.loads(raw.decode()) if raw else {}
    return raw


def _download_artifact(artifact_id: str, dest_dir: str) -> None:
    """Fetch a repo artifact zip from inside the runner (GitHub-internal network).

    The API 303-redirects to a signed blob URL; the bearer token must NOT be
    forwarded to that redirect, so the redirect is followed manually.
    """
    api_url = f"https://api.github.com/repos/{REPO}/actions/artifacts/{artifact_id}/zip"
    opener = urllib.request.build_opener(urllib.request.HTTPRedirectHandler)
    req = urllib.request.Request(api_url, headers={
        "Authorization": f"Bearer {GH_TOKEN}",
        "Accept": "application/vnd.github+json",
    })
    # urllib follows 303 automatically but keeps the Authorization header on the
    # redirect; the signed blob rejects it. Resolve the Location ourselves.
    class _NoRedirect(urllib.request.HTTPRedirectHandler):
        def redirect_request(self, *args, **kwargs):
            return None

    no_redirect = urllib.request.build_opener(_NoRedirect)
    try:
        no_redirect.open(req, timeout=60)
        blob = b""
    except urllib.error.HTTPError as e:
        if e.code not in (301, 302, 303, 307, 308):
            raise SystemExit(f"artifact {artifact_id} -> HTTP {e.code}: "
                             f"{e.read().decode()[:300]}")
        location = e.headers["Location"]
        blob = _raw_request("GET", location, expect_json=False)

    zpath = os.path.join(dest_dir, f"artifact-{artifact_id}.zip")
    with open(zpath, "wb") as f:
        f.write(blob)
    with zipfile.ZipFile(zpath) as z:
        z.extractall(dest_dir)
    print(f"Artifact {artifact_id}: {len(blob)} bytes extracted to {dest_dir}")


def _find_frame(dest_dir: str, basename: str) -> str:
    for root, _, files in os.walk(dest_dir):
        if basename in files:
            return os.path.join(root, basename)
    raise SystemExit(f"Frame {basename} not found under {dest_dir}")


def _png_size(path: str):
    with open(path, "rb") as f:
        data = f.read()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise SystemExit(f"Not a PNG: {path}")
    w, h = struct.unpack(">II", data[16:24])
    return w, h, len(data)


def _sha256(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()[:16]


def _existing_review_screenshot(token: str, sub_id: str):
    res = api("GET", f"/v1/subscriptions/{sub_id}/appStoreReviewScreenshot", token)
    return res.get("data")


def attach_review_screenshot(token: str, sub_id: str, png_path: str, label: str) -> None:
    w, h, size = _png_size(png_path)
    print(f"[{label}] {os.path.basename(png_path)} {w}x{h} {size} bytes")

    existing = _existing_review_screenshot(token, sub_id)
    if existing:
        old_id = existing["id"]
        state = (existing.get("attributes") or {}) \
            .get("assetDeliveryState", {}).get("state")
        print(f"[{label}] replacing existing screenshot {old_id} ({state}).")
        api("DELETE", f"/v1/subscriptionAppStoreReviewScreenshots/{old_id}", token)

    with open(png_path, "rb") as f:
        payload = f.read()

    created = api("POST", "/v1/subscriptionAppStoreReviewScreenshots", token, {
        "data": {
            "type": "subscriptionAppStoreReviewScreenshots",
            "attributes": {
                "fileName": os.path.basename(png_path),
                "fileSize": size,
            },
            "relationships": {
                "subscription": {"data": {"type": "subscriptions", "id": sub_id}}
            },
        }
    })
    shot = created["data"]
    shot_id = shot["id"]
    ops = shot["attributes"].get("uploadOperations") or []
    if not ops:
        raise SystemExit(f"[{label}] no uploadOperations in reservation {shot_id}")

    for op in ops:
        headers = {hd["name"]: hd["value"]
                    for hd in (op.get("requestHeaders") or [])}
        off = op.get("offset") or 0
        length = op.get("length") or len(payload)
        chunk = payload[off:off + length]
        _raw_request(op["method"], op["url"], data=chunk,
                     headers=headers, expect_json=False)

    api("PATCH", f"/v1/subscriptionAppStoreReviewScreenshots/{shot_id}", token, {
        "data": {
            "type": "subscriptionAppStoreReviewScreenshots",
            "id": shot_id,
            "attributes": {"uploaded": True, "sourceFileChecksum": None},
        }
    })

    state = None
    for _ in range(6):
        time.sleep(2)
        chk = api("GET", f"/v1/subscriptionAppStoreReviewScreenshots/{shot_id}", token)
        state = (chk["data"].get("attributes") or {}) \
            .get("assetDeliveryState", {}).get("state")
        if state in ("COMPLETE", "UPLOAD_COMPLETE"):
            print(f"[{label}] committed, state={state} ({shot_id})")
            return
    raise SystemExit(f"[{label}] screenshot did not reach COMPLETE; last state={state}")


def run_attach_screenshots(token: str) -> None:
    work = os.path.join(WORK, "attach-shots")
    os.makedirs(work, exist_ok=True)
    iphone_artifact = os.environ.get("ARTIFACT_IPHONE", "15027283002")

    plan = [
        {"sub": "6838602869", "frame": "05-paywall-yearly.png", "label": "yearly"},
        {"sub": "6838602473", "frame": "06-paywall-monthly.png", "label": "monthly"},
    ]
    _download_artifact(iphone_artifact, work)
    frames = {}
    for item in plan:
        png = _find_frame(work, item["frame"])
        digest = _sha256(png)
        frames[item["label"]] = digest
        print(f"[{item['label']}] {item['frame']} sha256={digest}")
        attach_review_screenshot(token, item["sub"], png, item["label"])
    if frames.get("yearly") == frames.get("monthly"):
        raise SystemExit("ERROR: yearly and monthly paywall frames are identical; "
                         "check the -plan= preselection before resubmitting.")
    print("All subscription review screenshots attached.")


def main():
    token = mint_jwt()
    command = sys.argv[1] if len(sys.argv) > 1 else "submit"

    if command == "inspect":
        run_inspect(token)
        return

    if command == "prepare":
        run_prepare(token)
        return

    if command == "attach-screenshots":
        run_attach_screenshots(token)
        return

    version = pick_inflight_version(token)
    version_id = version["id"]
    attrs = version["attributes"]
    print(f"Target version {attrs.get('versionString')} ({version_id}), "
          f"state {attrs.get('appStoreState')}")

    submission_id = open_submission(token)

    def attach_item(rel_name: str, rel_type: str, rel_id: str) -> None:
        api("POST", "/v1/reviewSubmissionItems", token, {
            "data": {
                "type": "reviewSubmissionItems",
                "relationships": {
                    "reviewSubmission": {
                        "data": {"type": "reviewSubmissions", "id": submission_id}
                    },
                    rel_name: {"data": {"type": rel_type, "id": rel_id}},
                },
            }
        })

    # Pro subscription versions ride along with this binary; submit the version,
    # not the parent subscription. Skip cleanly if none are in a submittable state.
    for sv in collect_submission_subscription_versions(token):
        attach_item("subscriptionVersion", "subscriptionVersions", sv["id"])
        print(f"Attached subscription version {sv['id']} "
              f"({sv['productId']}, {sv['state']}) to submission {submission_id}")

    attach_item("appStoreVersion", "appStoreVersions", version_id)
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
