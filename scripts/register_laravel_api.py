#!/usr/bin/env python3
"""Add explicit API and private mobile broadcast routing to Laravel 12."""
from pathlib import Path
import sys

path = Path(sys.argv[1])
contents = path.read_text()
api_anchor = "web: __DIR__.'/../routes/web.php',"
api_route = "api: __DIR__.'/../routes/api.php'"
if api_route not in contents:
    if contents.count(api_anchor) != 1:
        raise SystemExit('Unsupported Laravel bootstrap/app.php structure.')
    contents = contents.replace(
        api_anchor,
        api_anchor + "\n        api: __DIR__.'/../routes/api.php',\n        apiPrefix: 'api',",
        1,
    )

if '->withBroadcasting(' not in contents:
    anchor = '    ->withMiddleware('
    if contents.count(anchor) != 1:
        raise SystemExit('Unable to insert broadcasting routes safely.')
    contents = contents.replace(
        anchor,
        """    ->withBroadcasting(
        __DIR__.'/../routes/channels.php',
        ['prefix' => 'api', 'middleware' => ['api', 'auth:sanctum', 'throttle:dilemin-api']],
    )
""" + anchor,
        1,
    )

path.write_text(contents)
print('API and Sanctum-protected broadcasting auth routes registered.')
