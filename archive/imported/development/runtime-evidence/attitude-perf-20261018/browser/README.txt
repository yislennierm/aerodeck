CURRENT LOCAL AERODECK PREVIEW

This folder hosts a disposable TX16S native simulator. It snapshots the current
canonical app at /Users/nene/Documents/fpv-1/radiomaster_tx16s_mkII/LUA and uses a
development-only widget wrapper to supply sample telemetry. It never writes the
canonical project or radio. Normal roll display is selected. No instruction
budget override or forced fixture garbage collection is used.

Restart the current preview after source changes:
  python3 work/edgetx/current-preview-20261018/restart.py --port 8766

For a candidate without replacing the public preview, use --port 8767. The two
ports share this folder's private simulator SD image, so stop the other owned
server before rebuilding; the helper rejects simultaneous owned servers. It also
rejects an occupied port before preparing files. The helper only stops PIDs whose exact command belongs
to this folder. It will not stop the old power-live server.

Allow about 20 seconds for the cold bootstrap and native Full screen entry.
Then check endpoints and capture the native Flight display:
  python3 work/edgetx/current-preview-20261018/verify.py --port 8766

Inspect flight-8766.png: endpoint success alone does not prove a valid PFD.
Review the matching log for QA_DEV_ERROR or CPU limit before promoting a build.
The page is explicitly LOCAL / NOT INSTALLED / SAMPLE TELEMETRY. It is not a
physical radio performance measurement or a release acceptance result.

GET /build reports the frozen main hash, all 64 production runtime asset hashes,
fixture driver hashes, and drift from current canonical source. Frame and input
requests require the page's X-AERODECK-Source identity. Changed canonical source
blocks them until the server is restarted; refresh the browser afterward.

Owned process metadata: server-8766.json or server-8767.json.
Owned log: server-8766.log or server-8767.log.
Stop only an owned server:
  python3 work/edgetx/current-preview-20261018/restart.py --port 8766 --stop

Automated tour.py --extrema and motion.py change simulator screens. Run them
without concurrent browser interaction; manual touches invalidate their
assumptions about which native page is visible.
