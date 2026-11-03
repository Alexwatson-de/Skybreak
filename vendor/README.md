# Godot web template

`godot-web-4.5.1.zip` contains the official Godot 4.5.1 stable `web_nothreads_release.zip` export template. It is unchanged from the official export-template distribution. Vendoring this 9 MB archive avoids downloading every platform's export templates in each Vercel build.

Godot is MIT licensed. Its license and full third-party notices are retained in `docs/licenses/` and copied into the browser export. Official release: https://github.com/godotengine/godot/releases/tag/4.5.1-stable . The engine download used in Linux builds is independently checked by `scripts/verify_engine.py` using GitHub's official SHA-256 release-asset digest.
