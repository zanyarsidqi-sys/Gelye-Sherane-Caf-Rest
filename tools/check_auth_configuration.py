"""Validate public client configuration without logging keys or making logins."""
import json
import os
import re
import sys
import urllib.error
import urllib.request


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise ValueError("Authentication endpoint redirects are forbidden")


def validate(url, project_ref, key, opener=None):
    if opener is None:
        opener = urllib.request.build_opener(NoRedirect).open
    if not re.fullmatch(r"[a-z0-9]{20}", project_ref):
        raise ValueError("Invalid expected Supabase project reference")
    if url != f"https://{project_ref}.supabase.co":
        raise ValueError("Supabase URL does not match the expected project")
    publishable = re.fullmatch(r"sb_publishable_[A-Za-z0-9_-]+", key)
    legacy = re.fullmatch(r"eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+", key)
    if not publishable and not legacy:
        raise ValueError("Expected a Supabase public client key, not an account password or secret key")
    if legacy:
        import base64
        try:
            payload = key.split(".")[1]
            claims = json.loads(base64.urlsafe_b64decode(payload + "=" * (-len(payload) % 4)))
        except Exception:
            raise ValueError("Malformed legacy client key") from None
        if claims.get("role") != "anon" or claims.get("ref") != project_ref:
            raise ValueError("Legacy key must be an anon key for the expected project")
    request = urllib.request.Request(url + "/auth/v1/settings", headers={"apikey": key})
    try:
        with opener(request, timeout=20) as response:
            if response.geturl() != request.full_url:
                raise ValueError("Unexpected authentication endpoint redirect")
            settings = json.load(response)
    except urllib.error.HTTPError as error:
        raise ValueError(f"Auth configuration rejected (HTTP {error.code}); no key values logged") from None
    except urllib.error.URLError:
        raise ValueError("Auth configuration check could not reach Supabase") from None
    if settings.get("external", {}).get("email") is not True:
        raise ValueError("Email authentication is not enabled")


if __name__ == "__main__":
    try:
        validate(
            os.environ.get("PRODUCTION_SUPABASE_URL", ""),
            os.environ.get("PRODUCTION_SUPABASE_EXPECTED_PROJECT_REF", ""),
            os.environ.get("PRODUCTION_SUPABASE_ANON_KEY", ""),
        )
    except ValueError as error:
        print(f"Auth preflight failed: {error}", file=sys.stderr)
        sys.exit(1)
    print("PASS: configured public key accepted and email authentication enabled. Employee login/MFA not tested.")
