#!/usr/bin/env python3
"""Register API routing in a freshly generated Laravel 12 skeleton."""
from pathlib import Path
import sys

path = Path(sys.argv[1])
contents = path.read_text()
if "api: __DIR__.'/../routes/api.php'" in contents:
    print('Laravel API routing already configured.')
    sys.exit(0)
needle = "web: __DIR__.'/../routes/web.php',"
if contents.count(needle) != 1:
    raise SystemExit('Unsupported Laravel bootstrap/app.php structure; refusing silent edit.')
contents = contents.replace(needle, needle + "\n        api: __DIR__.'/../routes/api.php',\n        apiPrefix: 'api',", 1)
path.write_text(contents)
print('Registered Laravel API routes.')
