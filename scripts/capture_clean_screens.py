#!/usr/bin/env python3
"""
Roomlyst Clean Android Screen Capture Harness (Prompt 14).
Handles virtual keyboard dismissals and navigates all functional app screens on Samsung SM-A085F.
"""

import subprocess
import time
from pathlib import Path

OUT_DIR = Path("docs/ai/task-reports/14-evidence/android/screenshots")
OUT_DIR.mkdir(parents=True, exist_ok=True)

def adb(args):
    return subprocess.run(["adb"] + args, capture_output=True, text=True)

def ensure_app_foreground():
    adb(["shell", "input", "keyevent", "224"])  # Wake
    adb(["shell", "input", "keyevent", "82"])   # Unlock
    adb(["shell", "am", "start", "-n", "com.roomlyst.app/com.roomlyst.roomlyst.MainActivity"])
    time.sleep(2.0)

def tap(x, y, wait=1.5):
    adb(["shell", "input", "tap", str(x), str(y)])
    time.sleep(wait)

def back(wait=1.2):
    adb(["shell", "input", "keyevent", "4"])
    time.sleep(wait)

def swipe(x1, y1, x2, y2, duration=400, wait=1.5):
    adb(["shell", "input", "swipe", str(x1), str(y1), str(x2), str(y2), str(duration)])
    time.sleep(wait)

def capture(name, description=""):
    remote_path = f"/sdcard/{name}"
    adb(["shell", "screencap", "-p", remote_path])
    time.sleep(0.4)
    local_path = OUT_DIR / name
    res = subprocess.run(["adb", "pull", remote_path, str(local_path)], capture_output=True, text=True)
    if local_path.is_file():
        sz = local_path.stat().st_size
        print(f"[*] Captured {name} ({sz:,} bytes) - {description}")
        return sz
    else:
        print(f"[!] FAILED {name}: {res.stderr}")
        return 0

def run():
    print("Starting clean screen capture sequence on Samsung SM-A085F...")

    # Screen 1: Home / Project List
    ensure_app_foreground()
    time.sleep(1.0)
    capture("001-project-list.png", "Homeowner My Projects primary screen")

    # Screen 2: Hardware Simulation Bottom Sheet
    tap(360, 270, wait=1.8)
    capture("002-device-capability-sheet.png", "Hardware Simulation (Section 9) adaptive degradation bottom sheet")
    back(wait=1.2) # Close sheet

    # Screen 3: New Project Dialog (with keyboard open)
    tap(620, 560, wait=2.0)
    capture("003-create-project-dialog.png", "Create New Project modal dialog with virtual keyboard")
    back(wait=1.0) # Dismiss keyboard
    back(wait=1.2) # Dismiss dialog

    # Screen 4: Server Settings (Tap Gear icon: 600, 115)
    tap(600, 115, wait=2.5)
    capture("004-server-settings.png", "Server Settings configuration and connection diagnostic screen")
    swipe(360, 1200, 360, 600, duration=400, wait=1.5)
    capture("005-server-settings-scrolled.png", "Server Settings scrolled diagnostics view")
    back(wait=1.8) # Back to project list

    # Screen 5: Client Directory (Tap People icon: 500, 115)
    tap(500, 115, wait=2.5)
    capture("006-client-directory.png", "Client Directory CRM and contact management screen")
    back(wait=1.8) # Back to project list

    # Screen 6: Delete Confirmation Dialog (Tap trash on project card: 615, 710)
    tap(615, 710, wait=1.8)
    capture("007-delete-confirmation.png", "Project deletion confirmation dialog with data-purge warning")
    # Tap Cancel button (left side of dialog actions): X=470, Y=900
    tap(470, 900, wait=1.5)

    # Screen 7: Project Workspace Hub (Tap project card body: 360, 710)
    tap(360, 710, wait=3.0)
    capture("008-project-workspace.png", "Project Workspace primary hub for 'living room'")
    swipe(360, 1300, 360, 600, duration=500, wait=2.0)
    capture("009-project-workspace-modules.png", "Project Workspace modules: Budget, Materials, Staging, Export")
    swipe(360, 1300, 360, 600, duration=500, wait=2.0)
    capture("010-project-workspace-actions.png", "Project Workspace bottom controls and action buttons")

    # Scroll back up to top of workspace
    swipe(360, 600, 360, 1300, duration=400, wait=1.2)
    swipe(360, 600, 360, 1300, duration=400, wait=1.5)

    # Screen 8: Client Presentation Mode (Tap presentation icon in workspace AppBar: 550, 115)
    tap(550, 115, wait=2.5)
    capture("011-client-presentation.png", "Client Presentation full-screen mode")
    back(wait=1.8) # Return to workspace

    # Screen 9: Export Dossier (Tap export icon in workspace AppBar: 630, 115)
    tap(630, 115, wait=2.5)
    capture("012-export-dossier.png", "Branded Dossier & PDF Export screen")
    back(wait=1.8) # Return to workspace

    # Back to Project List
    back(wait=2.0)

    # Screen 10: Sign Out / Login Screen (Tap Logout icon: 680, 115)
    tap(680, 115, wait=2.5)
    capture("013-login-screen.png", "Authentication & Google Sign-In / Guest Entry screen")

    # Tap Guest Sign In button (X=360, Y=1300) to return to main screen
    tap(360, 1300, wait=3.0)
    capture("014-restored-session.png", "Restored guest session returning to My Projects")

    print("\n[+] Clean Screen Capture Sequence Finished Successfully.")

if __name__ == "__main__":
    run()
