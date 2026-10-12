from pathlib import Path
s=(Path(__file__).resolve().parents[1]/"web/push_client.js").read_text()
b=s[s.index("window.cafePushDisable ="):]
assert b.index("validateConfig(config)") < b.index("await api(config, 'unsubscribe'") < b.index("subscription.unsubscribe()")
assert "if (!raw) throw Error" in b
print("PASS")
