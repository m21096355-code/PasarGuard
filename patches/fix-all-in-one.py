#!/usr/bin/env python3
"""
Patch PasarGuard to run Xray node agent locally in ALL_IN_ONE mode.
This installs the node binary and creates a startup script.
"""
import os
import sys

# Read the main.py
with open("main.py", "r") as f:
    content = f.read()

# Check if already patched
if "start_node_agent" in content:
    print("ALREADY PATCHED")
    sys.exit(0)

# Add node agent startup to main.py
node_agent_code = '''

import subprocess
import signal
import time
import threading

_node_process = None

def start_node_agent():
    """Start the PasarGuard node agent in ALL_IN_ONE mode."""
    global _node_process
    node_binary = "/usr/local/bin/pasarguard-node"
    if not os.path.exists(node_binary):
        print(f"[PATCH] Node binary not found at {node_binary}")
        return
    
    # Get panel URL from env
    panel_url = os.environ.get("SUB_PUBLIC_HOST", os.environ.get("RAILWAY_PUBLIC_DOMAIN", "localhost"))
    if panel_url and not panel_url.startswith("http"):
        panel_url = f"https://{panel_url}"
    
    print(f"[PATCH] Starting node agent, panel URL: {panel_url}")
    
    # Start node agent in background
    try:
        _node_process = subprocess.Popen(
            [node_binary, "run", "--panel", panel_url],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
        )
        print(f"[PATCH] Node agent started with PID {_node_process.pid}")
    except Exception as e:
        print(f"[PATCH] Failed to start node agent: {e}")

def stop_node_agent():
    """Stop the node agent."""
    global _node_process
    if _node_process:
        try:
            _node_process.terminate()
            _node_process.wait(timeout=5)
        except:
            _node_process.kill()
        print("[PATCH] Node agent stopped")
'''

# Insert before the uvicorn.run call
if "__name__" in content:
    content = content.replace(
        'if __name__ == "__main__":',
        node_agent_code + '\nif __name__ == "__main__":'
    )
    
    # Add node agent start in the main block
    content = content.replace(
        'uvicorn.run(',
        'start_node_agent()\n    uvicorn.run('
    )

with open("main.py", "w") as f:
    f.write(content)

print("PATCHED: main.py updated to start node agent")
