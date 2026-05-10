import argparse
import json
import re
import sys
from pathlib import Path

from playwright.sync_api import sync_playwright


DEFAULT_LOGIN_PATTERNS = [
    r"登录",
    r"注册",
    r"\blogin\b",
    r"sign\s*in",
    r"sign\s*up",
]


def parse_args():
    parser = argparse.ArgumentParser(
        description="Verify browser session state by checking whether the homepage still shows login options."
    )
    parser.add_argument("--state-path", required=True)
    parser.add_argument("--url", required=True)
    parser.add_argument("--browser", default="chromium")
    parser.add_argument("--check-selector")
    parser.add_argument("--timeout-ms", type=int, default=60000)
    parser.add_argument("--headless", choices=["true", "false"], default="true")
    parser.add_argument("--login-pattern", action="append", dest="login_patterns")
    return parser.parse_args()


def normalize_browser_name(name: str) -> str:
    value = (name or "chromium").lower()
    if value in {"cr", "chrome", "chromium"}:
        return "chromium"
    if value in {"ff", "firefox"}:
        return "firefox"
    if value in {"wk", "webkit"}:
        return "webkit"
    return value


def main():
    args = parse_args()
    state_path = Path(args.state_path)
    if not state_path.exists():
        raise FileNotFoundError(f"State file does not exist: {state_path}")

    login_patterns = args.login_patterns or DEFAULT_LOGIN_PATTERNS
    login_regex = re.compile("|".join(login_patterns), re.IGNORECASE)
    browser_name = normalize_browser_name(args.browser)

    with sync_playwright() as p:
        browser_launcher = getattr(p, browser_name)
        browser = browser_launcher.launch(headless=args.headless == "true")
        context = browser.new_context(storage_state=str(state_path))
        page = context.new_page()
        page.goto(args.url, wait_until="networkidle", timeout=args.timeout_ms)

        title = page.title()
        final_url = page.url
        body_text = page.locator("body").inner_text(timeout=min(args.timeout_ms, 10000))
        clickable_items = page.locator("a,button,[role='button']").evaluate_all(
            """
            els => els
              .map(el => ({
                text: (el.innerText || '').trim(),
                href: el.href || null
              }))
              .filter(item => item.text)
            """
        )

        matched_login_items = []
        for item in clickable_items:
            if login_regex.search(item["text"]):
                matched_login_items.append(item)

        selector_visible = False
        if args.check_selector:
            locator = page.locator(args.check_selector).first
            selector_visible = locator.is_visible(timeout=min(args.timeout_ms, 5000))

        logged_in = selector_visible or len(matched_login_items) == 0
        reason = (
            "check_selector_visible"
            if selector_visible
            else "login_option_detected"
            if matched_login_items
            else "no_login_option_detected"
        )

        result = {
            "loggedIn": logged_in,
            "reason": reason,
            "title": title,
            "finalUrl": final_url,
            "checkUrl": args.url,
            "statePath": str(state_path),
            "checkSelector": args.check_selector,
            "selectorVisible": selector_visible,
            "matchedLoginItems": matched_login_items[:20],
            "clickableSample": clickable_items[:50],
            "textSample": body_text[:2000],
        }
        print(json.dumps(result, ensure_ascii=False, indent=2))
        browser.close()


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main()
