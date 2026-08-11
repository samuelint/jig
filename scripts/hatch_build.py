"""Custom build script for hatch backend."""  # noqa: INP001

import subprocess
from pathlib import Path

from hatchling.builders.hooks.plugin.interface import BuildHookInterface  # type: ignore

FRONTEND_PATH = Path("jig") / "jig_panel" / "frontend"
BUNDLE_PATH = FRONTEND_PATH / "dist"

MISSING_COREPACK_MESSAGE = (
    "Building the operator panel frontend requires corepack, which ships with "
    "Node.js 20 and later."
)


class CustomHook(BuildHookInterface):
    """Bundles the operator panel frontend into the distribution.

    The bundle is not committed, so a build from a fresh checkout - a `pip
    install` from git, for instance - has to produce it. Without it the panel
    has no static files to serve and fails to start.
    """

    def initialize(self, version: str, build_data: dict) -> None:  # noqa: ARG002
        """Build the frontend bundle unless the build tree already has one."""
        root = Path(self.root)
        if (root / BUNDLE_PATH).is_dir():
            return

        frontend_path = root / FRONTEND_PATH
        _run_yarn(frontend_path, "install")
        _run_yarn(frontend_path, "build")


def _run_yarn(frontend_path: Path, *arguments: str) -> None:
    # Through corepack rather than a bare `yarn`, so the build always uses the
    # version pinned in package.json instead of whichever yarn is installed.
    command = ["corepack", "yarn", *arguments]
    try:
        completed = subprocess.run(command, cwd=frontend_path, check=False)  # noqa: S603
    except FileNotFoundError as error:
        raise OSError(MISSING_COREPACK_MESSAGE) from error

    if completed.returncode:
        msg = f"`{' '.join(command)}` failed while building the operator panel"
        raise OSError(msg)
