import json
import os
import sys
import uuid

def get_settings_path():
    config_home = os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config"))
    paths = [
        os.path.join(config_home, "com.thebguy.gitdesktop", "settings.json"),
        os.path.join(os.path.expanduser("~/.local/share"), "com.thebguy.gitdesktop", "settings.json"),
    ]
    for p in paths:
        if os.path.exists(p):
            return p
    return paths[0]

def main():
    if len(sys.argv) < 2:
        print("Usage: inject_gitdesktop_mcp.py <repo_path>")
        sys.exit(1)
    
    repo_path = sys.argv[1]
    settings_path = get_settings_path()
    
    os.makedirs(os.path.dirname(settings_path), exist_ok=True)
    
    data = {}
    if os.path.exists(settings_path):
        try:
            with open(settings_path, "r") as f:
                data = json.load(f)
        except Exception as e:
            print(f"[PERINGATAN] Gagal membaca {settings_path}: {e}")
    
    settings = data.get("settings", {})
    if not isinstance(settings, dict):
        settings = {}
        
    mcp_servers = settings.get("mcpServers", [])
    if not isinstance(mcp_servers, list):
        mcp_servers = []
        
    mcp_servers = [s for s in mcp_servers if s.get("name") not in ("gitrs", "filesystem")]
    
    mcp_servers.append({
        "id": str(uuid.uuid4()),
        "name": "gitrs",
        "description": "Git status, diff, branch, staging, commit",
        "enabled": True,
        "scope": "global",
        "transport": "stdio",
        "command": "gitrs-mcp",
        "args": ["--repo", repo_path],
        "env": [],
        "url": "",
        "headers": [],
        "secretKeys": []
    })
    
    mcp_servers.append({
        "id": str(uuid.uuid4()),
        "name": "filesystem",
        "description": "Read, write, modify files",
        "enabled": True,
        "scope": "global",
        "transport": "stdio",
        "command": "mcp-filesystem-server",
        "args": [repo_path],
        "env": [],
        "url": "",
        "headers": [],
        "secretKeys": []
    })
    
    settings["mcpServers"] = mcp_servers
    data["settings"] = settings
    
    with open(settings_path, "w") as f:
        json.dump(data, f, indent=2)
    
    print(f"[OK]   Konfigurasi MCP disuntikkan secara otomatis ke {settings_path}")

if __name__ == "__main__":
    main()
