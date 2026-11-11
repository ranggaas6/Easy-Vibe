#!/usr/bin/env python3
import subprocess
from mcp.server.mcpserver import MCPServer

mcp = MCPServer("multi-git")

def run_git(repo_path, args):
    try:
        res = subprocess.run(
            ["git", "-C", repo_path] + args,
            capture_output=True,
            text=True,
            check=True
        )
        return res.stdout or "(no output)"
    except subprocess.CalledProcessError as e:
        return f"[ERROR] Git command failed with exit code {e.returncode}\n{e.stderr}\n{e.stdout}"
    except Exception as e:
        return f"[ERROR] {str(e)}"

@mcp.tool()
def git_status(repo_path: str) -> str:
    """Get the current Git status of a repository (branch, changes, etc)."""
    return run_git(repo_path, ["status"])

@mcp.tool()
def git_diff(repo_path: str, staged: bool = False) -> str:
    """Show the diff of changes in a repository. Set staged=true for staged changes only."""
    args = ["diff"]
    if staged:
        args.append("--staged")
    return run_git(repo_path, args)

@mcp.tool()
def git_log(repo_path: str, limit: int = 10) -> str:
    """Show recent commit history of a repository."""
    return run_git(repo_path, ["log", f"-n{limit}", "--oneline"])

@mcp.tool()
def git_branch_list(repo_path: str) -> str:
    """List all local branches in a repository."""
    return run_git(repo_path, ["branch"])

@mcp.tool()
def git_branch_create(repo_path: str, branch_name: str, checkout: bool = True) -> str:
    """Create a new branch in a repository, optionally checking it out."""
    if checkout:
        return run_git(repo_path, ["checkout", "-b", branch_name])
    else:
        return run_git(repo_path, ["branch", branch_name])

@mcp.tool()
def git_checkout(repo_path: str, branch_name: str) -> str:
    """Checkout an existing branch in a repository."""
    return run_git(repo_path, ["checkout", branch_name])

@mcp.tool()
def git_add(repo_path: str, files: str = ".") -> str:
    """Stage files for commit in a repository."""
    return run_git(repo_path, ["add", files])

@mcp.tool()
def git_commit(repo_path: str, message: str) -> str:
    """Commit staged changes in a repository with a message."""
    return run_git(repo_path, ["commit", "-m", message])

@mcp.tool()
def git_pull(repo_path: str) -> str:
    """Pull changes from the remote in a repository."""
    return run_git(repo_path, ["pull"])

@mcp.tool()
def git_push(repo_path: str) -> str:
    """Push committed changes to the remote in a repository."""
    return run_git(repo_path, ["push"])

@mcp.tool()
def git_read_file(repo_path: str, file_path: str) -> str:
    """Read the contents of a file inside a repository."""
    try:
        full_path = f"{repo_path}/{file_path}"
        with open(full_path, "r", encoding="utf-8") as f:
            return f.read()
    except Exception as e:
        return f"[ERROR] Failed to read file: {str(e)}"

if __name__ == "__main__":
    mcp.run()
