# Install and release

This guide installs the mod from the repository into one game or into every game of the launcher's list, and
publishes a release. Install when a change is finished and its tests pass; publish once the release's changelog is
written.

## Starting point

- The launcher's console, `pokeessentialsaccess-launcher.exe`. Take it from a release of the mod, or build it in the
  launcher's repository, `PokeEssentialsAccessInstaller`, with `cargo build --release`, which leaves it in
  `target/x86_64-pc-windows-msvc/release/`. The steps below write its path as `<launcher>`.
- A shell at the root of this repository. With `local`, the console takes the mod from the current folder or a folder
  above it. `--from <folder>` names another tree, such as a worktree.
- The game closed. The console stops with exit code 5 while the game runs.

`<launcher> help` prints every command and option. The same list ships beside the launcher as `commands.txt`.

## Installing in one game

1. Run `<launcher> local install "<game folder>" --yes`.
2. If the catalog does not recognize the game, add `--profile <key>`, with the name of a folder in `games/`, or
   `generic` for the generic profile. Without it, `--yes` leaves the console no way to ask, and it exits with code 4.
3. Check the install with `<launcher> local status "<game folder>"`. It prints the installed version and profile.
4. Start the game. `accessibility/data/preload_started.txt` in the game's folder shows that the preload ran, and
   `accessibility/data/loader_error.txt` lists what failed to load ([Loading](../architecture/loading.md)).

Installing over an install updates it in place and keeps `accessibility/data/`, with the player's `settings.ini` and
tags. A game still on the RPG Maker XP player moves to the mkxp-z build that its catalog entry names (`convert`). A
game that no entry converts gets an experimental conversion, after a warning.

`<launcher> local uninstall "<game folder>"` removes the mod and its data; `--keep-data` keeps `accessibility/data/`.

## Installing in every game

1. Put each game in the launcher's list once, with `<launcher> list add "<game folder>"` or by installing it as above:
   a folder not in the list joins it.
2. Run `<launcher> local install all --yes --no-pause --quiet`. The console installs three games at a time;
   `--jobs <n>` sets any number from 1 to 16.
3. Check the result with `<launcher> local status all`. Exit code 6 means that some games failed, and their lines say
   which.

The list is the `config.json` in the launcher's settings folder, `%APPDATA%\PokeEssentialsAccessLauncher` on Windows.
The environment variable `PEA_CONFIG_DIR` names another folder, which keeps a separate list, such as one of test games.

## Publishing a release

Start from `main`, with every change of the release committed and the changelog written in a file.

1. Check the tree as CI does (`.github/workflows/ci.yml`):
   - `ruby -c` on every `.rb` file under `core/`, `games/`, `plugins/`, `loader/` and `test/`.
   - `ruby test/run_all.rb` with no filter. Its output must contain `the whole suite:`, which the gen-6 pass prints
     only when no filter applies (`test/run.rb`). The static checks run with it, among them the Ruby 1.8.7 sweep,
     which needs Python ([Tests](tests.md)).
   - Every profile loaded alone with `Harness.load_all` from `test/support/harness.rb`, as the `profiles` step of
     `ci.yml` does for each folder of `games/` with a manifest.

   CI runs on Linux with Ruby 3.3. A path whose letter case differs from the file's, or a method newer than Ruby 3.3,
   can pass on Windows with a newer Ruby and fail there.
2. Search the files to publish for control characters and for paths of the local machine. The suite checks neither.
3. If the launcher changed, release it first, from its repository:
   1. Raise `version` in its `Cargo.toml`, commit and push.
   2. Tag `v<version>` and push the tag. Its release workflow stops when the tag and `Cargo.toml` differ. It runs the
      launcher's tests, builds it and publishes the exe and `commands.txt`.
4. In `version.json`, set `version` to the new version and `launcher` to the launcher version that this release ships.
   Commit. CI fails while that launcher version has no release with its exe.
5. Tag the release commit with the changelog: `git tag -a v<version> --cleanup=verbatim -F <changelog file>`. Without
   `--cleanup=verbatim`, git deletes every line of the message that starts with `#`, the Markdown headings among them.
6. Push the tag alone, with `git push origin v<version>`. The release workflow (`.github/workflows/release.yml`) runs
   the checks of CI again, writes the release's `version.json` and takes the exe and `commands.txt` from the
   launcher's release. It publishes four assets: `PokeEssentialsAccess_<tag>.zip`, its `.sha256`, `version.json` and
   the launcher's exe. The tag's message becomes the release notes.
7. When the release lists its four assets, push `main`.

The release page shows the four assets, with the changelog as its notes.

### Order of the tag and main

Launchers install the mod from the tree of `main`. The launcher's self-update reads `launcher` from the `version.json`
of `main` and downloads the exe from the newest published release of the mod that carries one
(`src/core/selfupdate.rs` in the launcher's repository). If `main` goes first, a launcher older than that version
downloads the previous release's exe, is still older after the update, and keeps updating until the release is out.
