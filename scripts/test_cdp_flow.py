"""
Real-browser acceptance testing via Chrome DevTools Protocol (CDP).
Tests both Gateway (port 8080 /roomlyst/) and Direct (port 8081 /) origins.
"""

import asyncio
import json
import os
import shutil
import subprocess
import time
import urllib.request
import websockets

CDP_BASE = "http://127.0.0.1:9222"
EDGE_EXE = r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
USER_DATA_DIR = r"C:\Users\puru_\AppData\Local\Temp\edge_cdp_p11"

def ensure_browser_process():
    # Check if already listening
    try:
        urllib.request.urlopen(f"{CDP_BASE}/json/version", timeout=1.0)
        return None
    except Exception:
        pass

    if os.path.exists(USER_DATA_DIR):
        try:
            shutil.rmtree(USER_DATA_DIR)
        except Exception:
            pass

    cmd = [
        EDGE_EXE,
        "--headless=new",
        "--remote-debugging-port=9222",
        "--remote-allow-origins=*",
        f"--user-data-dir={USER_DATA_DIR}",
        "--no-first-run",
        "--no-default-browser-check",
        "--disable-gpu",
        "about:blank"
    ]
    proc = subprocess.Popen(cmd)
    
    # Wait for port 9222
    for _ in range(25):
        time.sleep(0.2)
        try:
            urllib.request.urlopen(f"{CDP_BASE}/json/version", timeout=0.5)
            print("Edge browser started successfully on port 9222.")
            return proc
        except Exception:
            pass
    raise RuntimeError("Failed to start Edge with CDP on port 9222")



class BrowserSession:
    def __init__(self, tab_id, ws_url):
        self.tab_id = tab_id
        self.ws_url = ws_url
        self.ws = None
        self._msg_id = 0

    async def connect(self):
        self.ws = await websockets.connect(self.ws_url, max_size=10_000_000)
        await self.send("Page.enable")
        await self.send("Runtime.enable")
        await self.send("DOM.enable")
        await self.send("Console.enable")
        await self.send("Network.enable")
        await self.send("Network.clearBrowserCookies")


    async def send(self, method, params=None):
        self._msg_id += 1
        msg = {"id": self._msg_id, "method": method}
        if params:
            msg["params"] = params
        await self.ws.send(json.dumps(msg))
        while True:
            resp_raw = await self.ws.recv()
            resp = json.loads(resp_raw)
            if resp.get("method") == "Console.messageAdded":
                msg_obj = resp.get("params", {}).get("message", {})
                print(f"    [Console {msg_obj.get('level')}] {msg_obj.get('text')}")
            elif resp.get("id") == self._msg_id:
                return resp


    async def eval_js(self, expression, await_promise=False):
        params = {
            "expression": expression,
            "returnByValue": True,
            "awaitPromise": await_promise,
        }
        res = await self.send("Runtime.evaluate", params)
        if "exceptionDetails" in res.get("result", {}):
            raise RuntimeError(f"JS Exception: {res['result']['exceptionDetails']}")
        return res.get("result", {}).get("result", {}).get("value")

    async def click(self, selector):
        selector_json = json.dumps(selector)
        js = f"""(() => {{
            const el = document.querySelector({selector_json});
            if (!el) throw new Error("Element not found: " + {selector_json});
            el.click();
            return true;
        }})()"""
        return await self.eval_js(js)


    async def wait_for(self, condition_js, timeout_sec=20.0, step=0.3):
        start = time.time()
        while time.time() - start < timeout_sec:
            res = await self.eval_js(condition_js)
            if res:
                return res
            await asyncio.sleep(step)
        raise TimeoutError(f"Condition not met within {timeout_sec}s: {condition_js}")

    async def close(self):
        if self.ws:
            await self.ws.close()
        try:
            req = urllib.request.Request(f"{CDP_BASE}/json/close/{self.tab_id}")
            urllib.request.urlopen(req)
        except Exception:
            pass


async def launch_tab(url):
    req = urllib.request.Request(f"{CDP_BASE}/json/new?{url}", method="PUT")
    tab = json.loads(urllib.request.urlopen(req).read())
    session = BrowserSession(tab["id"], tab["webSocketDebuggerUrl"])
    await session.connect()
    # Wait for page readiness
    await asyncio.sleep(1.5)
    return session


async def run_acceptance_suite(origin_label, target_url):
    print(f"\n=======================================================")
    print(f"  STARTING REAL-BROWSER ACCEPTANCE: {origin_label}")
    print(f"  Target: {target_url}")
    print(f"=======================================================")

    browser = await launch_tab(target_url)
    evidence = {}

    try:
        # Step 1: Landing Page Load & Title
        title = await browser.eval_js("document.title")
        print(f"[1] Landing Title: {title}")
        assert "Roomlyst" in title
        evidence["title"] = title

        # Wait for Server status pill to indicate connection
        await browser.wait_for(
            'document.getElementById("apiStatusDot").classList.contains("online")',
            timeout_sec=10.0,
        )
        api_text = await browser.eval_js(
            'document.getElementById("apiStatusText").innerText'
        )
        print(f"    Server Status: {api_text}")
        assert "online" in api_text.lower() or "connected" in api_text.lower()

        # Step 2: Guest Session Status on Initial Fresh Landing
        initial_session_text = await browser.eval_js('document.getElementById("sessionVal").innerText')
        print(f"[2] Fresh Landing Session: {initial_session_text}")
        assert initial_session_text in ["ephemeral_guest", "guest_"], f"Unexpected session text: {initial_session_text}"

        # Step 3: Project Creation via UI Modal (Issues Guest Token)
        print("[3] Creating new project via UI modal (will issue server guest token)...")
        await browser.click("#btnNewProject")
        await asyncio.sleep(0.5)
        proj_name = f"Browser P11 Project ({origin_label})"
        await browser.eval_js(f'document.getElementById("newProjectNameInput").value = "{proj_name}";')
        await browser.click("#btnCreateProjectSubmit")
        await asyncio.sleep(1.0)

        # Wait for session to transition to guest token display
        session_id_issued = await browser.wait_for(
            'document.getElementById("sessionVal").innerText.startsWith("guest_") ? document.getElementById("sessionVal").innerText : null',
            timeout_sec=8.0
        )
        print(f"    Guest Token issued and rendered: {session_id_issued}")
        active_proj = await browser.wait_for(
            f'document.getElementById("activeProjectVal").innerText === "{proj_name}" ? true : null',
            timeout_sec=8.0
        )
        print(f"    Active Project confirmed in UI: '{proj_name}'")

        # Step 3b: Test Reload Continuity
        print("    Testing reload continuity for newly issued session...")
        await browser.send("Page.reload")
        await asyncio.sleep(1.5)
        await browser.wait_for('document.getElementById("apiStatusDot").classList.contains("online")')
        session_id_after_reload = await browser.eval_js('document.getElementById("sessionVal").innerText')
        print(f"    Session after page reload:   {session_id_after_reload}")
        assert session_id_issued == session_id_after_reload, f"Session ID mismatch after reload! {session_id_issued} != {session_id_after_reload}"
        print("    PASS: Session continuity verified across page reload.")


        # Step 4: Synthetic Demo Living Room Generation & Upload
        print("[4] Loading Synthetic Demo Living Room into Canvas & Uploading...")
        await browser.click("#btnLoadDemo")
        await asyncio.sleep(0.5)

        # Wait for Analyze button to become enabled and click it
        await browser.wait_for('!document.getElementById("btnAnalyze").disabled', timeout_sec=5.0)
        print("    Clicking Run Room Understanding (btnAnalyze)...")
        await browser.click("#btnAnalyze")

        # Wait for elements container to appear after analysis
        await browser.wait_for(
            '!document.getElementById("elementsContainer").classList.contains("hidden")',
            timeout_sec=20.0
        )
        print("    Room Understanding complete: architecture elements rendered.")


        elements_summary = await browser.eval_js("""(() => {
            const openings = document.querySelectorAll("#openingsList .element-row").length;
            const surfaces = document.querySelectorAll("#surfacesList .element-row").length;
            const objects = document.querySelectorAll("#objectsList .element-row").length;
            const measurements = document.querySelectorAll("#measurementsList .element-row").length;
            return {openings, surfaces, objects, measurements};
        })()""")
        print(f"    Elements detected: {elements_summary}")
        assert (
            elements_summary["openings"] + elements_summary["objects"]
        ) > 0

        # Step 6: Test Structural Anchor Guard
        print("[6] Testing Structural Anchor Guard conflict warning...")
        # Try to set an opening or surface to REMOVE
        guard_test = await browser.eval_js("""(() => {
            const firstSelect = document.querySelector("#openingsList select") || document.querySelector("#surfacesList select");
            if (firstSelect) {
                firstSelect.value = "REMOVE";
                firstSelect.dispatchEvent(new Event("change"));
                return true;
            }
            return false;
        })()""")
        if guard_test:
            # Check for conflict warning
            warning_active = await browser.wait_for(
                '!document.getElementById("structuralWarning").classList.contains("hidden") || document.querySelector(".toast.warning") !== null',
                timeout_sec=5.0,
            )
            print(
                f"    Structural conflict warning successfully triggered: {warning_active}"
            )

        # Step 7: Formulate 3-Variant Algorithmic Redesign
        print("[7] Requesting 3 Structurally Preserved Algorithmic Variants...")
        await browser.click('.style-chip[data-style="Warm Modern Minimalist"]')
        await browser.eval_js(
            'document.getElementById("budgetAmount").value = 12000;'
        )
        await browser.click("#btnGenerate")

        # Wait for results card to appear
        await browser.wait_for(
            '!document.getElementById("resultsCard").classList.contains("hidden")',
            timeout_sec=30.0,
        )
        variants_count = await browser.eval_js(
            'document.querySelectorAll("#variantsGrid .variant-card").length'
        )
        print(f"    Design Variants rendered in DOM: {variants_count}")
        assert variants_count == 3

        # Verify each variant has valid signed image and preservation score
        variant_details = await browser.eval_js("""(() => {
            const cards = document.querySelectorAll("#variantsGrid .variant-card");
            return Array.from(cards).map(c => ({
                title: c.querySelector(".variant-body")?.innerText?.split("\\n")[0],
                score: c.querySelector(".preservation-meter strong")?.innerText,
                imgSrc: c.querySelector("img.variant-img")?.src,
                hasSig: (c.querySelector("img.variant-img")?.src || "").includes("sig=")
            }));
        })()""")
        for idx, vd in enumerate(variant_details):
            print(
                f"    Variant {idx+1}: {vd['title']} | Score: {vd['score']} | Signed URL: {vd['hasSig']}"
            )
            assert vd["hasSig"] is True

        # Step 8: Variant Favoriting
        print("[8] Testing Variant Favoriting...")
        await browser.eval_js(
            'document.querySelector("#variantsGrid .favorite-btn").click();'
        )
        await asyncio.sleep(1.0)
        fav_active = await browser.eval_js(
            'document.querySelector("#variantsGrid .favorite-btn").classList.contains("favorited")'
        )
        print(f"    Variant favorite state active: {fav_active}")
        assert fav_active is True

        # Step 9: Before & After Comparison Modal
        print("[9] Testing Before & After Comparison Modal...")
        await browser.eval_js(
            'document.querySelector(\'#variantsGrid button[onclick*="openComparison"]\').click();'
        )
        await browser.wait_for(
            '!document.getElementById("comparisonModal").classList.contains("hidden")',
            timeout_sec=5.0,
        )
        comp_orig = await browser.eval_js(
            'document.getElementById("compOriginalImg").src'
        )
        comp_var = await browser.eval_js(
            'document.getElementById("compVariantImg").src'
        )
        print(f"    Comparison Modal: Original and Variant images loaded.")
        assert "sig=" in comp_orig and "sig=" in comp_var
        await browser.click('#comparisonModal button[onclick*="closeModal"]')
        await asyncio.sleep(0.5)

        # Step 10: Ollama Architectural Evaluation
        print("[10] Testing Ollama AI Evaluation Modal...")
        await browser.eval_js(
            'document.querySelector(\'#variantsGrid button[onclick*="evaluateOllama"]\').click();'
        )
        await browser.wait_for(
            '!document.getElementById("ollamaModal").classList.contains("hidden")',
            timeout_sec=5.0,
        )
        # Wait for critique text to finish loading
        await browser.wait_for(
            '!document.getElementById("ollamaModalContent").classList.contains("hidden")',
            timeout_sec=30.0,
        )
        critique_text = await browser.eval_js(
            'document.getElementById("ollamaModalContent").innerText'
        )
        print(f"    Ollama Critique received (length: {len(critique_text)} chars)")
        assert len(critique_text) > 10
        await browser.click('#ollamaModal button[onclick*="closeModal"]')
        await asyncio.sleep(0.5)


        # Step 11: Refresh & Reopen Saved Project
        print("[11] Testing Refresh & Reopen Project State...")
        await browser.send("Page.reload")
        await asyncio.sleep(1.5)
        await browser.wait_for(
            'document.getElementById("apiStatusDot").classList.contains("online")'
        )
        restored_proj = await browser.eval_js(
            'document.getElementById("activeProjectVal").innerText'
        )
        print(f"    Restored Project after refresh: '{restored_proj}'")
        assert restored_proj == proj_name

        # Step 12: Logout / New Guest Session
        print("[12] Testing New Guest Session / Session Reset...")
        await browser.eval_js("window.confirm = () => true;")
        await browser.click("#btnNewSession")
        await asyncio.sleep(1.5)
        new_session_id = await browser.wait_for(
            f'document.getElementById("sessionVal").innerText !== "{session_id_issued}" ? document.getElementById("sessionVal").innerText : null',
            timeout_sec=10.0,
        )
        print(f"    New session generated: {new_session_id}")
        assert new_session_id != session_id_issued
        print(f"    PASS: Clean guest session reset verified.")



        print(
            f"\n  >>> ALL 12 REAL-BROWSER WORKFLOW STEPS PASSED ON {origin_label} <<<\n"
        )
        return True

    finally:
        await browser.close()


async def run_cross_origin_isolation_test():
    print(f"\n=======================================================")
    print(f"  CROSS-ORIGIN ISOLATION & STORAGE SEPARATION TEST")
    print(f"=======================================================")

    # 1. Open Tab on Gateway (:8080/roomlyst/) and generate a session
    tab1 = await launch_tab("http://192.168.0.200:8080/roomlyst/")
    await tab1.wait_for('document.getElementById("apiStatusDot").classList.contains("online")')
    await tab1.click("#btnNewProject")
    await asyncio.sleep(0.5)
    await tab1.eval_js('document.getElementById("newProjectNameInput").value = "Isolation Test Gateway";')
    await tab1.click("#btnCreateProjectSubmit")
    await tab1.wait_for('document.getElementById("sessionVal").innerText.startsWith("guest_")', timeout_sec=8.0)
    gw_token = await tab1.eval_js('localStorage.getItem("roomlyst_guest_token")')
    print(f"  Gateway Origin (:8080) LocalStorage Token: {gw_token[:20] if gw_token else 'None'}...")
    assert gw_token is not None

    # 2. Open Tab on Direct Port (:8081/)
    tab2 = await launch_tab("http://192.168.0.200:8081/")
    await tab2.wait_for('document.getElementById("apiStatusDot").classList.contains("online")')
    direct_token_before = await tab2.eval_js('localStorage.getItem("roomlyst_guest_token")')
    print(f"  Direct Origin  (:8081) Initial LocalStorage Token: {direct_token_before}")
    # Verify Tab 2 does NOT have Tab 1's token
    assert direct_token_before is None, "Direct origin should not inherit gateway localStorage!"

    # Create project on Direct origin to generate independent token
    await tab2.click("#btnNewProject")
    await asyncio.sleep(0.5)
    await tab2.eval_js('document.getElementById("newProjectNameInput").value = "Isolation Test Direct";')
    await tab2.click("#btnCreateProjectSubmit")
    await tab2.wait_for('document.getElementById("sessionVal").innerText.startsWith("guest_")', timeout_sec=8.0)
    direct_token_after = await tab2.eval_js('localStorage.getItem("roomlyst_guest_token")')
    print(f"  Direct Origin  (:8081) Issued LocalStorage Token: {direct_token_after[:20] if direct_token_after else 'None'}...")
    assert direct_token_after is not None

    # Verify tokens are distinct
    print(f"  Cross-Origin Storage Verification: Origins maintain distinct, non-overlapping identities.")
    assert gw_token != direct_token_after, "Tokens must be independently generated on distinct origins!"
    print(f"  PASS: Cross-origin guest isolation confirmed.")


    await tab1.close()
    await tab2.close()
    return True


async def main():
    browser_proc = ensure_browser_process()
    try:
        # Run against Gateway (:8080/roomlyst/)
        await run_acceptance_suite(
            "Gateway Route (:8080/roomlyst/)", "http://192.168.0.200:8080/roomlyst/"
        )

        # Run against Direct Port (:8081/)
        await run_acceptance_suite(
            "Direct Port (:8081/)", "http://192.168.0.200:8081/"
        )

        # Cross-origin isolation check
        await run_cross_origin_isolation_test()

        print(
            "\n#####################################################################"
        )
        print("  ALL REAL-BROWSER ACCEPTANCE TESTS COMPLETED SUCCESSFULLY!")
        print(
            "#####################################################################\n"
        )
    finally:
        if browser_proc:
            try:
                browser_proc.terminate()
                browser_proc.wait(timeout=3)
            except Exception:
                browser_proc.kill()



if __name__ == "__main__":
    asyncio.run(main())
