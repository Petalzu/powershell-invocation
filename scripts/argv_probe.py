import json
import sys

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

print(
    json.dumps(
        {
            "argv": sys.argv[1:],
            "stdin_encoding": sys.stdin.encoding,
            "stdout_encoding": sys.stdout.encoding,
        },
        ensure_ascii=False,
    )
)
