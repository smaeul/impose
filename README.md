# Impose - bend machines to follow your will

`impose` provides both declarative and procedural configuration tools for
POSIX-compatible operating systems, using the universally-available programming
language: POSIX `sh`. When used locally, `impose` requires no dependencies
beyond a POSIX-compatible shell and utilities. Remote use of `impose` also
requires `ssh(1)` and optionally `sudo(8)`.

## General usage

```
sh impose.sh [HOST [HOST...]]
sh impose.sh -m <MODULE> [HOST [HOST...]]
```

`impose` searches for all of its configuration and data files in the current
working directory, so there is no need to install it. An installation target
(`make install`) is provided only for convenience.

## Hosts

`impose` can operate on an arbitrary set of hostnames or FQDNs. For each
hostname or FQDN other than those with a host part of `localhost`, `impose`
will connect to the remote machine via `ssh(1)`, copy itself and its
configuration to a temporary directory, and then re-run itself. It will use
`sudo(8)` as necessary to elevate to UID 0.

If no positional arguments are provided or the hostname `localhost` is given,
and `impose` is running as root, it will make changes to the local machine.

If a module name (see below) is provided with the `-m` option on the command
line, that module will be applied to all hosts. Otherwise, `impose` will search
for a file containing a list of modules to apply in order (one per line).

First, it will look for a file in `hosts` with a name that exactly matches the
name given on the command line. Second, if the name given on the command line
was a FQDN, `impose` will look for a file in `hosts` matching only the host
part (the part of the FQDN before the first dot). Finally, still no matching
file is found, the file `hosts/default` will be used.

A warning will be printed for each host where an exact match was not found.

## Modules

Configuration is divided into modules. Each host can use an arbitrary set of
modules, and each module can be used on an arbitrary set of hosts. Modules are
assumed to be independent; any dependencies between modules must be handled
manually, e.g. by the order of modules declared in host files.

Modules are represented by a directory, `modules/<MODULE>`, and consist of a
set of control files, and zero or more subdirectories containing data files.

The following control files are available and are examined in order, if
present:
- `pre`, a POSIX shell script that will be run on the target
- `directories`, a list of directories that will be created on the target
- `files`, a list of files that will be copied to the target
- `post`, a POSIX shell script that will be run on the target

### Directories

The format of this file is one directory per line, with up to four
whitespace-separated fields:

- Full directory path
- Permissions (octal)
- Owning user or UID
- Owning group or GID

Missing parent directories will not be created and will produce an error.

### Files

The format of this file is one file per line, with up to four
whitespace-separated fields:

- Full file path
- Permissions (octal)
- Owning user or UID
- Owning group or GID

The contents of a file will come from a file of the same path relative to the
module directory. For example, if the `base` module wanted to supply the
file `/etc/shells`, its contents would come from the source file
`modules/base/etc/shells`. The source file is required, even if it is empty.
The owner and permissions of the source file are ignored.

Files will only be copied if their contents differe from the source file
contents. The owner and permissions will be updated regardless of if the file
contents have changed.

The SHA-512 checksum of each copied file will be stored in the file
`/etc/.impose_manifest` on the target system. If a file is listed in this
manifest, and the existing version of the file does not match the hash in the
manifest, then the existing version of the file will be backed up (with a
suffix `.impose-old`) before being overwritten.

Missing parent directories will not be created and will produce an error.

### Pre/post scripts

These are arbitrary shell scripts that can be used for any purpose, such as
removing or modifying existing files, installing packages, and starting or
restarting services.

The following environment variables will be available to these scripts:
- `IMPOSE`: a non-empty string
- `MODSRC`: the path of the module source directory, with no trailing slash
- `MODULE`: the name of the module
- `NO_ACTION`: a positive integer if the script should make no changes
- `ROOT`: the root of the destination directory hierarchy, with no trailing
  slash (i.e. nominally the empty string)
- `VERBOSE`: a positive integer if the script should print additional messages

These scripts will run with a `umask` of `0577`, which means that files and
directories created by these scripts will be inaccessible to other users by
default. Script authors will need to manually set the permissions of each
created file, or change the `umask` inside the script.
