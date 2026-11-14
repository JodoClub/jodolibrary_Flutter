import sys
import json
import urllib.request
import urllib.parse
from datetime import datetime

WEBHOOK_URL = "https://script.google.com/macros/s/AKfycbzt9Mpl30eYf08PJDN1sw2YWUpqahOsmtMb8IUBHZlPIHSt_iI08A9pdzImcIk2fBS0tQ/exec"

def send_feature_to_sheet(feature_name, category, description, third_party="None", status="Completed", date_time=None):
    # User rule: Do not log release, build, or APK deployment details to the sheet.
    # ONLY functional features developed in the app/backend must be logged.
    ignored_keywords = ["release", "apk", "ci/cd", "deployment", "git push"]
    if any(k in feature_name.lower() or k in category.lower() for k in ignored_keywords):
        print(f"[SKIP] '{feature_name}' ignored. Only functional feature developments are logged to the sheet.")
        return False, "Skipped: Release/Deployment details are excluded."

    if not date_time:
        date_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    payload = {
        "dateTime": date_time,
        "featureName": feature_name,
        "category": category,
        "description": description,
        "thirdParty": third_party,
        "status": status
    }

    req = urllib.request.Request(
        WEBHOOK_URL,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"}
    )

    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            body = resp.read().decode("utf-8")
            print(f"[OK] Feature logged: '{feature_name}' -> Response: {body}")
            return True, body
    except Exception as e:
        print(f"[ERROR] Failed to log feature '{feature_name}': {e}")
        return False, str(e)

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--test":
        send_feature_to_sheet(
            feature_name="Webhook Integration Test",
            category="Automation & DevOps",
            description="Testing automated Google Apps Script Webhook connection from Antigravity agent.",
            third_party="Google Apps Script, urllib.request",
            status="Verified"
        )
    elif len(sys.argv) >= 5:
        send_feature_to_sheet(
            feature_name=sys.argv[1],
            category=sys.argv[2],
            description=sys.argv[3],
            third_party=sys.argv[4],
            status=sys.argv[5] if len(sys.argv) > 5 else "Completed"
        )
    else:
        print("Usage:")
        print("  python scripts/log_feature.py --test")
        print('  python scripts/log_feature.py "Feature Name" "Category" "Description" "Third Party Info" ["Status"]')
