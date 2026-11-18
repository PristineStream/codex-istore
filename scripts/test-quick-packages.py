#!/usr/bin/env python3
"""Check the actual quick-build IPKs without installing them on the host."""
import io
import json
from pathlib import Path
import sys
import tarfile


def check_package(path):
    with tarfile.open(path) as package:
        archives = {}
        for name in ("control", "data"):
            member = next(m for m in package if m.name.lstrip("./") == name + ".tar.gz")
            archives[name] = tarfile.open(fileobj=io.BytesIO(package.extractfile(member).read()))
    for archive in archives.values():
        for member in archive:
            assert member.uid == member.gid == 0, f"{path.name}: non-root owner: {member.name}"
            if not member.issym():
                assert member.mode & 0o6022 == 0, f"{path.name}: unsafe permissions: {member.name}"
                assert member.mode in (0o644, 0o755), f"{path.name}: unexpected permissions: {member.name}"
    control = archives["control"].extractfile("./control").read().decode()
    fields = dict(line.split(": ", 1) for line in control.splitlines() if ": " in line)
    return fields, archives["data"]


def main():
    dist = Path(sys.argv[1])
    packages = {}
    for name in ("luci-app-codex-istore", "app-meta-codex-istore"):
        paths = list(dist.glob(name + "_*.ipk"))
        assert len(paths) == 1, f"Expected one package for {name}"
        packages[name] = check_package(paths[0])
    app, data = packages["luci-app-codex-istore"]
    meta, metadata = packages["app-meta-codex-istore"]
    assert app["Version"] == meta["Version"], "Package versions differ"
    assert app["Architecture"] == "x86_64" and meta["Architecture"] == "all"
    assert "luci-app-codex-istore" in meta["Depends"].split(", ")
    for executable in ("usr/bin/codex-istore", "usr/libexec/rpcd/luci.codex-istore",
                       "usr/share/codex-istore/register-desktop.sh"):
        assert data.getmember("./" + executable).mode == 0o755, executable
    link = data.getmember("./usr/share/linkease/apps.d/30-codex-istore.json")
    assert link.issym() and link.linkname == "/usr/share/codex-istore/codex-istore-plugin.json"
    manifest = json.load(data.extractfile("./usr/share/codex-istore/codex-istore-plugin.json"))
    assert manifest["desktop"]["props"]["initialPath"] == "/cgi-bin/luci/admin/services/codex-istore"
    info = json.load(metadata.extractfile("./usr/lib/opkg/meta/codex-istore.json"))
    assert app["Version"] == f'{info["version"]}-{info["release"]}'
    assert info["website"] == "https://github.com/easepi/codex-istore"
    print("Quick IPK ownership, permissions, versions, metadata and desktop registration: OK")


if __name__ == "__main__":
    main()
