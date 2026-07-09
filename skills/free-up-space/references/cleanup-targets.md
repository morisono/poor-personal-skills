# Cleanup Targets by Platform

Each target: what it is, how to measure, how to reclaim. All targets here are reproducible data — safe in the sense that the system or toolchain regenerates them on demand. Present sizes to the user before applying anything.

## Contents

- [Linux](#linux)
- [macOS](#macos)
- [Windows](#windows)
- [WSL](#wsl)
- [Containers and VMs](#containers-and-vms)
- [Developer toolchains](#developer-toolchains)

## Linux

| Target | Measure | Reclaim |
|--------|---------|---------|
| APT cache | `du -sh /var/cache/apt` | `sudo apt-get clean` |
| APT orphans | `apt-get -s autoremove` | `sudo apt-get autoremove --purge` |
| DNF cache | `du -sh /var/cache/dnf` | `sudo dnf clean all` |
| Pacman cache | `du -sh /var/cache/pacman/pkg` | `sudo paccache -rk2` (keep 2 versions) |
| journald logs | `journalctl --disk-usage` | `sudo journalctl --vacuum-size=200M` |
| Old logs | `du -sh /var/log` | `sudo find /var/log -name '*.gz' -o -name '*.1' -delete` — review first |
| Snap old revisions | `snap list --all \| awk '/disabled/'` | `sudo snap remove --revision=<rev> <name>`; also `sudo snap set system refresh.retain=2` |
| Flatpak unused | — | `flatpak uninstall --unused` |
| systemd coredumps | `du -sh /var/lib/systemd/coredump` | `sudo rm /var/lib/systemd/coredump/*` |
| /tmp aged files | `find /tmp -atime +7 -type f` | usually tmpfs — reboot clears; else delete aged files |
| Trash | `du -sh ~/.local/share/Trash` | `rm -rf ~/.local/share/Trash/{files,info}/*` or `trash-empty` |

Deleted-but-open files hold space: `sudo lsof +L1` lists them; restart the owning process.

## macOS

| Target | Measure | Reclaim |
|--------|---------|---------|
| Homebrew cache | `brew --cache` then `du -sh` | `brew cleanup --prune=all` |
| User caches | `du -sh ~/Library/Caches` | delete per-app subdirs; apps rebuild |
| Xcode DerivedData | `du -sh ~/Library/Developer/Xcode/DerivedData` | delete entirely |
| Xcode device support | `~/Library/Developer/Xcode/iOS DeviceSupport` | delete old OS versions |
| Simulators | `xcrun simctl list` | `xcrun simctl delete unavailable` |
| Time Machine local snapshots | `tmutil listlocalsnapshots /` | `tmutil deletelocalsnapshots <date>` |
| Trash | `du -sh ~/.Trash` | empty via Finder or `rm -rf ~/.Trash/*` |

## Windows

Prefer built-in mechanisms for anything under `C:\Windows` — manual deletion there breaks servicing.

| Target | Measure | Reclaim |
|--------|---------|---------|
| Temp files | `%TEMP%`, `C:\Windows\Temp` | delete contents (skip locked files) |
| Component store (WinSxS) | `Dism /Online /Cleanup-Image /AnalyzeComponentStore` | `Dism /Online /Cleanup-Image /StartComponentCleanup` |
| Update cache | `C:\Windows\SoftwareDistribution\Download` | stop `wuauserv`, delete contents, restart service |
| Disk Cleanup targets | — | `cleanmgr /sageset:1` then `cleanmgr /sagerun:1`, or Storage Sense |
| Recycle Bin | — | `Clear-RecycleBin -Force` |
| Hibernation file | `hiberfil.sys` size ≈ RAM | `powercfg /hibernate off` (only if hibernation unused) |
| Delivery Optimization | Settings → Storage | `Delete-DeliveryOptimizationCache` |
| Memory dumps | `C:\Windows\Minidump`, `MEMORY.DMP` | delete after confirming no pending analysis |

## WSL

Guest-side deletion does not shrink the host `.vhdx`. Two steps always:

1. Free space inside the distro (Linux table above; Docker Desktop data is often the bulk).
2. Compact the vhdx from Windows:

```powershell
wsl --shutdown
# locate vhdx: $env:LOCALAPPDATA\Packages\<distro>\LocalState\ext4.vhdx
Optimize-VHD -Path <path>\ext4.vhdx -Mode Full        # requires Hyper-V feature
# without Hyper-V: diskpart → select vdisk file="<path>" → attach vdisk readonly → compact vdisk → detach vdisk
```

WSL ≥ 2.0 alternative: enable sparse vhdx — `wsl --manage <distro> --set-sparse true`.

## Containers and VMs

| Target | Measure | Reclaim |
|--------|---------|---------|
| Docker overall | `docker system df` | `docker system prune` (add `-a` to drop all unused images — confirm first) |
| Docker build cache | `docker system df -v` | `docker builder prune` |
| Docker volumes | `docker volume ls -f dangling=true` | `docker volume prune` — volumes may hold unique data; list first |
| Podman | `podman system df` | `podman system prune` |
| Old VM disks/ISOs | scan for `*.vhdx *.vmdk *.qcow2 *.iso` | user decision — never auto-delete |

## Developer toolchains

| Target | Measure | Reclaim |
|--------|---------|---------|
| npm cache | `du -sh $(npm config get cache)` | `npm cache clean --force` |
| pnpm store | `pnpm store path` | `pnpm store prune` |
| yarn cache | `yarn cache dir` | `yarn cache clean` |
| stale `node_modules` | `find . -name node_modules -prune -type d` | delete in inactive projects; `npx npkill` for interactive |
| pip cache | `pip cache dir` + `du` | `pip cache purge` |
| uv cache | `uv cache dir` | `uv cache clean` |
| cargo | `~/.cargo/registry`, per-project `target/` | `cargo cache -a` (needs cargo-cache) or delete `target/` |
| Go | `go env GOCACHE GOMODCACHE` | `go clean -cache -modcache` |
| Gradle | `~/.gradle/caches` | `gradle --stop` then delete caches dir |
| Maven | `~/.m2/repository` | delete stale artifacts; re-downloads on build |
| Hugging Face | `~/.cache/huggingface` | `huggingface-cli delete-cache` (interactive) |
| Conda | `du -sh $(conda info --base)/pkgs` | `conda clean --all` |
| Nix store | `du -sh /nix/store` | `nix-collect-garbage -d` |
