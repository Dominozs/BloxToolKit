# Contributing

Thanks for considering a contribution to RbxToolkit!

## Setup

Tools are pinned in `rokit.toml`. With [rokit](https://github.com/rojo-rbx/rokit) installed:

```sh
rokit install
```

That gives you `lune`, `selene` and `stylua` at the versions CI uses.

## Local checks

Run all three before opening a pull request:

```sh
selene src tests examples
stylua --check src tests examples
lune run tests/run.luau
```

Tests run headlessly through `tests/run.luau` (a TestEZ-compatible harness) and also run unmodified in Studio.

## Before opening an issue

- Check whether a similar issue already exists.
- Include clear reproduction steps for bugs.
- Describe the expected and actual behavior.

## Pull requests

- Keep changes focused and explain why they are needed.
- Use strict Luau typing where practical.
- Include or update tests for behavior changes.
- Update documentation and examples when the public API changes.
- Do not include secrets, private game assets, or copyrighted material you do not have permission to distribute.

By submitting a contribution, you agree that it may be distributed under this repository's MIT license.
