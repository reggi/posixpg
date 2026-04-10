# posixpg

A Unix-like virtual filesystem implemented entirely in PostgreSQL. All filesystem semantics — users, groups, permissions, directories, files, and symbolic links — are emulated through PL/pgSQL functions, with a parity test suite that validates behavior against real Debian commands.

## How it works

Two parallel command implementations live in `commands/`:

- **`mmex_*`** — PostgreSQL-backed. Each command calls a PL/pgSQL function that operates on a virtual filesystem stored in the `files` table.
- **`debi_*`** — Debian-native. Thin wrappers around real Linux commands (`chmod`, `mkdir`, `chgrp`, etc.) running as actual system users.

YAML test specs in `spec/` run identical operations against both implementations and assert matching behavior — exit codes, stdout, and side effects.

## Quick start

```bash
# requires Docker
./utils/dockerrunner          # run all 42 specs
./utils/dockerrunner 7        # run spec 007
./utils/dockerrunner 7 10 23  # run multiple specs
```

## Commands

### File operations

| Command | Args | Description |
|---------|------|-------------|
| `mkdir` | `as_user path [mode]` | Create directory |
| `mkdir_p` | `as_user path [mode]` | Create directory and missing parents |
| `mkfile` | `as_user path content [mode]` | Create or overwrite file |
| `touch` | `as_user path` | Create empty file |
| `cat` | `as_user path` | Read file content |
| `append` | `as_user path content` | Append content to file |
| `ls` | `as_user path` | List directory contents |
| `find` | `as_user path [name_pattern]` | Search files recursively with glob pattern |
| `stat` | `as_user path` | Show file metadata (type, mode, owner, group) |
| `cp` | `as_user src dest` | Copy file |
| `mv` | `as_user src dest` | Move or rename file/directory |
| `rm` | `as_user path` | Delete file or directory recursively |
| `rmdir` | `as_user path` | Remove empty directory |
| `ln` | `as_user src dest` | Create symbolic link |
| `readlink` | `as_user path` | Show symlink target path |
| `test` | `as_user flag path` | Check file existence/type (`e`, `f`, `d`, `L`) |

### Permissions

| Command | Args | Description |
|---------|------|-------------|
| `chmod` | `as_user mode path` | Change permissions (owner or superuser only) |
| `chmod_r` | `as_user mode path` | Change permissions recursively |
| `chown` | `as_user new_owner path` | Change file owner (superuser only) |
| `chgrp` | `as_user group path` | Change file group (owner or superuser only) |
| `umask` | `[mask]` | Get or set default file creation mask |
| `checkauth` | `as_user path` | Check read/write/execute permissions |
| `fileperm` | `as_user path` | Show file permission bits |
| `getowner` | `path` | Show file owner |

### Users and groups

| Command | Args | Description |
|---------|------|-------------|
| `createuser` | `user password [createdir] [superuser]` | Create user, group, and home directory |
| `deleteuser` | `user` | Delete user, home directory, and primary group |
| `login` | `user password` | Authenticate with password |
| `passwd` | `user new_password` | Change user password |
| `id` | `user` | Show user info |
| `mkgroup` | `group` | Create a group |
| `addusertogroup` | `as_user group` | Add user to group |
| `listusergroups` | `user` | List user's groups |

### System

| Command | Args | Description |
|---------|------|-------------|
| `dirmodeset` | `mode` | Set default directory mode |
| `homeset` | `path` | Set default home directory path |

## Permission model

Follows Unix semantics:

- **Owner / Group / Other** permission bits (read, write, execute)
- **Directory traversal** requires execute on every ancestor
- **Group priority** — if user is in the file's group, group bits apply even if other bits are more permissive
- **Superuser** bypasses all permission checks
- **Symlink resolution** follows chains up to 50 hops, checks permissions on the resolved target
- **`rm` uses `unlink()` semantics** — checks write+execute on the parent directory, not the file
- **`umask`** — controls default permissions for new files (666 & ~umask) and directories
- **Path resolution** — supports `.` and `..` components

## Project structure

```
├── .github/workflows/ # CI test suite
├── sql/               # PL/pgSQL functions and table definitions (loaded in numeric order)
├── commands/
│   ├── mmex/          # PostgreSQL-backed command implementations
│   └── debi/          # Debian-native command wrappers
├── spec/              # YAML test specifications (42 parity tests)
├── utils/             # Test runner, DB tools, schema
└── Dockerfile         # postgres:15-bullseye with test dependencies
```

## Test specs

42 YAML specs in `spec/` validate parity between the PostgreSQL and Debian implementations, covering file operations, permissions, symlinks, groups, superuser bypass, hierarchy traversal, umask, recursive operations, and edge cases like mode 000 lockout recovery.

```bash
./utils/dockerrunner      # run all
./utils/dockerrunner 7 10 # run specific specs by number
```

## License

MIT
