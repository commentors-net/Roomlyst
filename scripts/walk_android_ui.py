#!/usr/bin/env python3
"""
Roomlyst Physical Android Visual Walkthrough & Evidence Capture (Prompt 14).
Navigates the installed Flutter application on Samsung Galaxy SM-A085F (720x1600).
Captures full-resolution PNG screenshots of all discovered screens and states.
"""

import subprocess
import time
from pathlib import Path

OUT_DIR = Path("docs/ai/task-reports/14-evidence/android/screenshots")
OUT_DIR.mkdir(parents=True, exist_ok=True)

def adb(args):
    return subprocess.run(["adb"] + args, capture_output=True, text=True)

def tap(x, y, wait=1.5):
    adb(["shell", "input", "tap", str(x), str(y)])
    time.sleep(wait)

def back(wait=1.2):
    adb(["shell", "input", "keyevent", "4"])
    time.sleep(wait)

def swipe(x1, y1, x2, y2, duration=300, wait=1.5):
    adb(["shell", "input", "swipe", str(x1), str(y1), str(x2), str(y2), str(duration)])
    time.sleep(wait)

def capture(name, description=""):
    remote_path = f"/sdcard/{name}"
    adb(["shell", "screencap", "-p", remote_path])
    time.sleep(0.5)
    local_path = OUT_DIR / name
    res = subprocess.run(["adb", "pull", remote_path, str(local_path)], capture_output=True, text=True)
    if local_path.is_file():
        sz = local_path.stat().st_size
        print(f"[*] Captured {name} ({sz:,} bytes) - {description}")
        return sz
    else:
        print(f"[!] FAILED to capture {name}: {res.stderr}")
        return 0

def main():
    print("==================================================")
    print("Roomlyst Android Physical Visual QA (Prompt 14)")
    print("Device: Samsung Galaxy SM-A085F (720x1600 @ 300dpi)")
    print(f"Output: {OUT_DIR}")
    print("==================================================")

    # Step 0: Ensure app is running on main screen
    adb(["shell", "am", "start", "-n", "com.roomlyst.app/com.roomlyst.roomlyst.MainActivity"])
    time.sleep(3.0)

    # 1. Main Project List Screen
    capture("001-project-list-home.png", "Homeowner My Projects primary dashboard")

    # 2. Hardware Capability Simulation Bottom Sheet (tap on Tier C card: 360, 270)
    tap(360, 270, wait=2.0)
    capture("002-device-capability-sheet.png", "Hardware Simulation (Section 9) adaptive degradation sheet")
    back(wait=1.5)

    # 3. New Project Dialog (tap + New Project: 620, 560)
    tap(620, 560, wait=2.0)
    capture("003-create-project-dialog.png", "Create New Project input dialog")
    # Cancel dialog (tap Cancel: 450, 930 approx or Back)
    back(wait=1.5)

    # 4. Server & App Settings Screen (tap Settings gear: 600, 115)
    tap(600, 115, wait=2.5)
    capture("004-server-settings-screen.png", "Server Settings configuration and connection tester")
    # Test connection button or scroll settings
    swipe(360, 1200, 360, 600, duration=400, wait=1.5)
    capture("005-server-settings-scrolled.png", "Server Settings scrolled view with advanced diagnostics")
    back(wait=2.0)

    # 5. Client Directory Screen (tap People icon: 500, 115)
    tap(500, 115, wait=2.5)
    capture("006-client-directory-screen.png", "Client Directory CRM workspace view")
    back(wait=2.0)

    # 6. Delete Project Confirmation Dialog (tap trash on project card: 615, 710)
    tap(615, 710, wait=1.8)
    capture("007-delete-project-dialog.png", "Delete project confirmation dialog with data-purge warning")
    # Cancel delete (tap Cancel or Back)
    back(wait=1.5)

    # 7. Open Project Workspace (tap on project card body: 360, 710)
    tap(360, 710, wait=3.0)
    capture("008-project-workspace-hub.png", "Project Workspace primary hub for 'living room'")

    # 8. Scroll Project Workspace Hub down to expose modules
    swipe(360, 1300, 360, 500, duration=500, wait=2.0)
    capture("009-project-workspace-modules.png", "Project Workspace modules: Budget, Materials, Staging, Export")

    # 9. Scroll further down in Workspace Hub
    swipe(360, 1300, 360, 500, duration=500, wait=2.0)
    capture("010-project-workspace-footer.png", "Project Workspace bottom controls and action buttons")

    # Return to top of workspace
    swipe(360, 500, 360, 1300, duration=400, wait=1.5)
    swipe(360, 500, 360, 1300, duration=400, wait=1.5)

    # 10. Tap Presentation Mode button if present in AppBar / workspace
    # Let's tap presentation icon or action button in workspace
    # First let's check action buttons: in workspace AppBar there are action icons
    # AppBar icons at X=550, Y=115 and X=630, Y=115
    tap(600, 115, wait=2.5)
    capture("011-workspace-appbar-action.png", "First workspace AppBar action screen")
    back(wait=2.0)

    # Exit workspace back to project list
    back(wait=2.0)

    # 11. Sign Out / Login Screen (tap Logout icon: 680, 115)
    tap(680, 115, wait=2.5)
    capture("012-login-screen.png", "Authentication & Google Sign-In / Guest Entry screen")

    # 12. Tap 'Continue as Guest' or 'Sign In as Guest' on Login screen to restore session
    # Guest button is typically near bottom, e.g. Y=1200 or Y=1300
    # Let's tap Guest Entry: 360, 1300
    tap(360, 1300, wait=3.0)
    capture("013-restored-session-home.png", "Restored guest session returning to My Projects")

    print("\n[+] Visual QA Walkthrough Complete.")

if __name__ == "__main__":
    main()
