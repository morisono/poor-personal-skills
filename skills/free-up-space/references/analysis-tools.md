# Disk Usage Analysis Tools

Selection guide and command recipes. All sizes reported by these tools are *used blocks* unless noted; use `--apparent-size` variants when comparing to file lengths.

## Selection

| Tool | Level | Interface | Pick when |
|------|-------|-----------|-----------|
| `dysk` | Filesystem/mount | Table, one-shot | Overview of mounts, free vs used, filter by disk type |
| `dua` | Directory/file | One-shot or TUI | Fast scan + interactive browse-and-delete; JSON for automation |
| `dust` | Directory/file | Tree, one-shot | Instant visual "what is big here" |
| `ncdu` | Directory/file | TUI | Ubiquitous (C, in most repos), remote servers, export/import scans |
| `duf` | Filesystem/mount | Table, one-shot | Pretty `df` replacement, JSON output |
| `erdtree` | Directory/file | Tree, one-shot | Tree view with icons, respects .gitignore |
| `broot` | Directory/file | TUI | Navigation-first with size mode (`br -w`) |
| WizTree / WinDirStat | Directory/file | GUI (Windows) | NTFS MFT-based scan (WizTree, fastest) or treemap (WinDirStat) |

Naming caveat: `dysk` here is dystroy's filesystem lister (https://dystroy.org/dysk). A different, unrelated project `khenidak/dysk` mounts Azure disks as kernel block devices — do not mix them up.

## dysk

Filesystem information as a table. Not for per-directory analysis.

```sh
dysk                                  # overview of usual disks
dysk --sort free                      # sort by free size
dysk --filter 'disk = HDD'            # only HDDs
dysk --filter 'use > 65% | free < 50G'  # high utilization or low free
dysk --json                           # machine-readable
```

## dua (dua-cli)

Parallel scanner with interactive mode. Best throughput on many-core machines.

```sh
dua <path>                    # aggregate usage of path
dua interactive               # TUI: browse, mark, delete
dua --apparent-size <path>    # file lengths instead of blocks
dua --count-hard-links        # count hard links every time seen
dua --format GB aggregate     # byte format: metric|binary|bytes|GB|GiB|MB|MiB
dua --threads 8 <path>        # cap threads
```

In interactive mode: `d` marks for deletion, `x` deletes marked, `o` opens.

## dust

du + tree, sorted by size, percent bars. Fastest way to answer "where did my space go".

```sh
dust                          # current directory
dust <dir1> <dir2>            # multiple roots
dust --depth 3                # limit depth
dust --number-of-lines 30     # show more entries (default 21)
dust --reverse                # biggest at top
dust --ignore-directory node_modules
dust --no-percent-bars
```

## ncdu

```sh
ncdu /                        # scan root (needs perms for full picture)
ncdu -x /                     # stay on one filesystem
ncdu -o scan.json / && ncdu -f scan.json   # scan once, browse later/elsewhere
```

`d` deletes selected entry (confirmation prompt). Use `--exclude` for mounts like `/proc`.

## Windows

- WizTree: reads NTFS MFT directly; full-drive scan in seconds. Requires admin for MFT mode.
- WinDirStat: treemap visualization, slower.
- Built-in: `Get-PSDrive C` for free space; Storage settings → Storage Sense for managed cleanup.

## Related

- https://github.com/muesli/duf
- https://github.com/solidiquis/erdtree
- https://github.com/Canop/broot
- https://github.com/topics/disk-usage
