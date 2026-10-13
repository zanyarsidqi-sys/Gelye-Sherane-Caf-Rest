from pathlib import Path
import io
import json
import sys
import unittest
import urllib.error

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from check_auth_configuration import validate

REF = "a" * 20
URL = f"https://{REF}.supabase.co"
KEY = "sb_publishable_synthetic_test"


class Response(io.StringIO):
    def geturl(self):
        return URL + "/auth/v1/settings"


class AuthConfigurationTests(unittest.TestCase):
    def test_valid_public_configuration(self):
        def opener(request, timeout):
            self.assertEqual(request.get_header("Apikey"), KEY)
            self.assertEqual(timeout, 20)
            return Response(json.dumps({"external": {"email": True}}))
        validate(URL, REF, KEY, opener)

    def test_password_secret_and_empty_rejected_without_network(self):
        for key in ("synthetic-password ", "sb_secret_test", ""):
            with self.subTest(key=key), self.assertRaises(ValueError):
                validate(URL, REF, key, lambda *a, **k: self.fail("Unexpected request"))

    def test_wrong_project_rejected(self):
        with self.assertRaises(ValueError):
            validate("https://other.supabase.co", REF, KEY)

    def test_api_rejection_redacted(self):
        def opener(*a, **k):
            raise urllib.error.HTTPError(URL, 401, KEY, {}, None)
        with self.assertRaises(ValueError) as caught:
            validate(URL, REF, KEY, opener)
        self.assertIn("401", str(caught.exception))
        self.assertNotIn(KEY, str(caught.exception))

    def test_email_disabled(self):
        with self.assertRaises(ValueError):
            validate(URL, REF, KEY, lambda *a, **k: Response('{"external":{"email":false}}'))

    def test_no_network_failure_is_success(self):
        def opener(*a, **k):
            raise urllib.error.URLError("offline")
        with self.assertRaises(ValueError):
            validate(URL, REF, KEY, opener)


if __name__ == "__main__":
    unittest.main()
