#!/usr/bin/env python3
# audit-brief: memantau log mcp-audit, menyimpan snapshot git ke refs/wip/autosave
# setelah tiap penulisan file, dan menulis brief.txt untuk melanjutkan di akun lain.
# Tidak menyentuh branch, index, atau riwayat repo. Hanya stdlib.
import glob, json, os, subprocess, sys, time

HOME = os.path.expanduser('~')
BASE = os.path.join(HOME, '.easy-vibe')
AUDIT = os.path.join(BASE, 'audit')
BRIEF = os.path.join(BASE, 'brief.txt')
REG = os.path.join(HOME, '.coding-mcp', 'registry.json')
WRITE_TOOLS = {'write_file', 'create_file', 'apply_patch', 'replace_in_file', 'move_file', 'delete_file'}
TAIL_BYTES = 262144
MAX_LOG_BYTES = 5 * 1024 * 1024
NL = chr(10)


def git(path, *args, env=None):
    try:
        r = subprocess.run(['git', '-C', path] + list(args), capture_output=True, text=True, timeout=30, env=env)
        return r.returncode, r.stdout.rstrip(chr(10))
    except Exception:
        return 1, ''


def projects():
    try:
        with open(REG) as f:
            d = json.load(f)
        return {p.get('id'): p.get('absolute_path') for p in d.get('projects', []) if p.get('id')}
    except Exception:
        return {}


def tail_events(n=400):
    events = []
    for fp in glob.glob(os.path.join(AUDIT, '*.jsonl')):
        try:
            size = os.path.getsize(fp)
            with open(fp, 'rb') as f:
                if size > TAIL_BYTES:
                    f.seek(size - TAIL_BYTES)
                lines = f.read().decode('utf-8', 'replace').splitlines()
            if size > TAIL_BYTES:
                lines = lines[1:]
            for line in lines:
                try:
                    events.append(json.loads(line))
                except Exception:
                    pass
        except Exception:
            pass
    events.sort(key=lambda e: e.get('timestamp', ''))
    return events[-n:]


def is_call(e):
    return e.get('direction') == 'request' and e.get('method') == 'tools/call'


def target(a):
    a = a or {}
    for k in ('path', 'source_path', 'message', 'query', 'repo_url', 'branch', 'pattern', 'command'):
        v = a.get(k)
        if v:
            return str(v).replace(NL, ' ')[:80]
    return ''


def snapshot(path):
    real = os.path.realpath(path)
    rc, top = git(real, 'rev-parse', '--show-toplevel')
    if rc != 0 or os.path.realpath(top) != real:
        return None
    rc, gd = git(real, 'rev-parse', '--absolute-git-dir')
    if rc != 0:
        return None
    tmp = os.path.join(gd, 'wip-index')
    env = dict(os.environ, GIT_INDEX_FILE=tmp)
    git(real, 'add', '-A', env=env)
    rc, tree = git(real, 'write-tree', env=env)
    try:
        os.remove(tmp)
    except OSError:
        pass
    if rc != 0 or not tree:
        return None
    _, prev = git(real, 'rev-parse', '-q', '--verify', 'refs/wip/autosave')
    _, head = git(real, 'rev-parse', '-q', '--verify', 'HEAD')
    parent = prev or head
    if parent:
        _, ptree = git(real, 'rev-parse', parent + '^{tree}')
        if ptree == tree:
            return prev or None
    cenv = dict(os.environ)
    for k, v in (('GIT_AUTHOR_NAME', 'easy-vibe'), ('GIT_AUTHOR_EMAIL', 'easy-vibe@localhost'),
                 ('GIT_COMMITTER_NAME', 'easy-vibe'), ('GIT_COMMITTER_EMAIL', 'easy-vibe@localhost')):
        cenv.setdefault(k, v)
    args = ['commit-tree', tree, '-m', 'wip autosave ' + time.strftime('%H:%M:%S')]
    if parent:
        args += ['-p', parent]
    rc, sha = git(real, *args, env=cenv)
    if rc != 0 or not sha:
        return None
    git(real, 'update-ref', 'refs/wip/autosave', sha)
    return sha


def write_brief(events, pm):
    calls = [e for e in events if is_call(e)][-10:]
    out = ['BRIEF ' + time.strftime('%Y-%m-%d %H:%M:%S'), '']
    out.append('10 panggilan terakhir (lama -> baru):')
    for e in calls:
        out.append('  %s %s/%s %s' % (str(e.get('timestamp', ''))[11:19], e.get('server_name', '?'), e.get('tool_name', '?'), target(e.get('arguments'))))
    last = {}
    for e in events:
        last[e.get('server_name', '?')] = e
    pending = [s for s, e in last.items() if is_call(e)]
    if pending:
        out.append('')
        out.append('MUNGKIN TERPUTUS (panggilan terakhir belum punya hasil): ' + ', '.join(pending))
        out.append('Periksa apakah perubahan terakhir benar-benar tertulis sebelum melanjutkan.')
    seen = []
    for e in reversed(calls):
        pid = (e.get('arguments') or {}).get('project_id')
        if pid and pid not in seen:
            seen.append(pid)
    for pid in seen[:3]:
        path = pm.get(pid)
        if not path:
            continue
        rc, _ = git(path, 'rev-parse', '--git-dir')
        if rc != 0:
            continue
        out.append('')
        out.append('Project %s -> %s' % (pid, path))
        _, br = git(path, 'rev-parse', '--abbrev-ref', 'HEAD')
        _, hd = git(path, 'log', '-1', '--format=%h %s')
        _, wp = git(path, 'rev-parse', '--short', '-q', '--verify', 'refs/wip/autosave')
        _, st = git(path, 'status', '--porcelain')
        out.append('  branch: %s | commit: %s | snapshot wip: %s' % (br, hd, wp or '-'))
        rows = st.splitlines()
        for r in rows[:15]:
            out.append('  ' + r)
        if len(rows) > 15:
            out.append('  ... +%d berkas lagi' % (len(rows) - 15))
    out.append('')
    out.append('Lanjut: jalankan git_status dan git_diff pada project di atas, lalu lanjutkan dari panggilan terakhir.')
    out.append('Snapshot otomatis (bukan commit di branch): git show refs/wip/autosave')
    tmp = BRIEF + '.tmp'
    with open(tmp, 'w') as f:
        f.write(NL.join(out) + NL)
    os.chmod(tmp, 0o600)
    os.replace(tmp, BRIEF)


def rotate_logs():
    # Salin lalu kosongkan (copytruncate) agar mcp-audit tetap menulis ke berkas yang sama.
    # Hanya satu cadangan (.1) per log. Cadangan tidak dibaca karena glob hanya *.jsonl.
    for fp in glob.glob(os.path.join(AUDIT, '*.jsonl')):
        try:
            if os.path.getsize(fp) <= MAX_LOG_BYTES:
                continue
            bak = fp + '.1'
            with open(fp, 'rb') as src, open(bak, 'wb') as dst:
                while True:
                    chunk = src.read(1048576)
                    if not chunk:
                        break
                    dst.write(chunk)
            os.chmod(bak, 0o600)
            with open(fp, 'r+b') as f:
                f.truncate(0)
        except Exception:
            pass


def signature():
    sig = []
    for p in sorted(glob.glob(os.path.join(AUDIT, '*.jsonl'))):
        try:
            sig.append((p, os.path.getsize(p)))
        except OSError:
            pass
    return tuple(sig)


def main():
    once = '--once' in sys.argv
    os.makedirs(AUDIT, exist_ok=True)
    seen = set()
    sig = None
    first = True
    while True:
        rotate_logs()
        s = signature()
        if s != sig:
            sig = s
            if not first:
                time.sleep(1.5)
            events = tail_events()
            pm = projects()
            todo = []
            for e in events:
                if not is_call(e):
                    continue
                eid = e.get('event_id')
                if eid in seen:
                    continue
                seen.add(eid)
                if not first and e.get('tool_name') in WRITE_TOOLS:
                    pid = (e.get('arguments') or {}).get('project_id')
                    if pid in pm and pm[pid] not in todo:
                        todo.append(pm[pid])
            for p in todo:
                snapshot(p)
            write_brief(events, pm)
            first = False
        if once:
            return
        time.sleep(2)


if __name__ == '__main__':
    main()
