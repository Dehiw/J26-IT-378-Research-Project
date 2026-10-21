"""Notebook subprocess diagnostics without starting training implicitly."""

from collections import deque
from datetime import datetime
from pathlib import Path
import os
import subprocess


def select_training_python(candidates):
    failures = []
    for executable in dict.fromkeys(str(path) for path in candidates):
        if not Path(executable).is_file():
            continue
        probe = subprocess.run(
            [executable, "-B", "-c", "import torch, torchvision, numpy, PIL, sklearn; print('torch', torch.__version__, 'torchvision', torchvision.__version__)"],
            capture_output=True, text=True, encoding="utf-8", errors="replace",
        )
        if probe.returncode == 0:
            print("Training Python:", executable)
            print(probe.stdout.strip())
            return executable
        failures.append(f"{executable}: {probe.stderr.strip().splitlines()[-1] if probe.stderr.strip() else 'dependency check failed'}")
    raise RuntimeError(
        "No candidate Python has working training dependencies.\n" + "\n".join(failures)
        + "\nInstall this model's requirements.txt into the selected Python environment, then rerun this preflight cell."
    )


def run_logged(args, *, cwd, log_dir):
    command = [str(value) for value in args]
    log_dir = Path(log_dir)
    log_dir.mkdir(parents=True, exist_ok=True)
    script_name = Path(command[1]).stem if len(command) > 1 else "command"
    log_path = log_dir / f"{script_name}_{datetime.now():%Y%m%d_%H%M%S_%f}.log"
    env = {**os.environ, "PYTHONUNBUFFERED": "1", "PYTHONIOENCODING": "utf-8"}
    print("Running:", subprocess.list2cmdline(command), flush=True)
    print("Output log:", log_path, flush=True)
    tail = deque(maxlen=40)
    with log_path.open("w", encoding="utf-8") as log:
        with subprocess.Popen(command, cwd=cwd, env=env, stdout=subprocess.PIPE,
                              stderr=subprocess.STDOUT, text=True, encoding="utf-8", errors="replace", bufsize=1) as process:
            try:
                for line in process.stdout:
                    print(line, end="", flush=True)
                    log.write(line)
                    log.flush()
                    tail.append(line)
                code = process.wait()
            except BaseException:
                process.terminate()
                process.wait()
                raise
    if code:
        raise RuntimeError(f"{script_name} exited with code {code}. Full output: {log_path}\n" + "".join(tail))
    return log_path
