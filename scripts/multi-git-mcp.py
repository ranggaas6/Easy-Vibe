#!/usr/bin/env python3
import sys
import json
import subprocess

def run_git(repo_path, args):
    try:
        res = subprocess.run(
            ["git", "-C", repo_path] + args,
            capture_output=True,
            text=True
        )
        if res.returncode == 0:
            return {"content": [{"type": "text", "text": res.stdout or "(no output)"}]}
        else:
            return {"content": [{"type": "text", "text": res.stderr or "(error)"}], "isError": True}
    except Exception as e:
        return {"content": [{"type": "text", "text": str(e)}], "isError": True}

def handle_request(req):
    method = req.get("method")
    req_id = req.get("id")

    if method == "initialize":
        return {
            "jsonrpc": "2.0",
            "id": req_id,
            "result": {
                "protocolVersion": "2024-11-05",
                "capabilities": {"tools": {}},
                "serverInfo": {"name": "multi-git", "version": "1.0.0"}
            }
        }

    if method == "tools/list":
        return {
            "jsonrpc": "2.0",
            "id": req_id,
            "result": {
                "tools": [
                    {
                        "name": "git_status",
                        "description": "Get git status of a repository",
                        "inputSchema": {
                            "type": "object",
                            "properties": {"repo_path": {"type": "string"}},
                            "required": ["repo_path"]
                        }
                    },
                    {
                        "name": "git_diff",
                        "description": "Get git diff of a repository",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "repo_path": {"type": "string"},
                                "staged": {"type": "boolean"}
                            },
                            "required": ["repo_path"]
                        }
                    },
                    {
                        "name": "git_log",
                        "description": "Get git log of a repository",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "repo_path": {"type": "string"},
                                "limit": {"type": "integer"}
                            },
                            "required": ["repo_path"]
                        }
                    },
                    {
                        "name": "git_commit",
                        "description": "Commit staged changes",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "repo_path": {"type": "string"},
                                "message": {"type": "string"}
                            },
                            "required": ["repo_path", "message"]
                        }
                    }
                ]
            }
        }

    if method == "tools/call":
        params = req.get("params", {})
        name = params.get("name")
        args = params.get("arguments", {})
        repo_path = args.get("repo_path")

        if name == "git_status":
            result = run_git(repo_path, ["status"])
        elif name == "git_diff":
            cmd = ["diff"]
            if args.get("staged"):
                cmd.append("--staged")
            result = run_git(repo_path, cmd)
        elif name == "git_log":
            limit = args.get("limit", 10)
            result = run_git(repo_path, ["log", f"-n{limit}", "--oneline"])
        elif name == "git_commit":
            result = run_git(repo_path, ["commit", "-m", args.get("message", "commit")])
        else:
            result = {"content": [{"type": "text", "text": "Unknown tool"}], "isError": True}

        return {
            "jsonrpc": "2.0",
            "id": req_id,
            "result": result
        }

    return {
        "jsonrpc": "2.0",
        "id": req_id,
        "error": {"code": -32601, "message": "Method not found"}
    }

def main():
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            req = json.loads(line)
            res = handle_request(req)
            if res:
                sys.stdout.write(json.dumps(res) + "\n")
                sys.stdout.flush()
        except Exception:
            pass

if __name__ == "__main__":
    main()
