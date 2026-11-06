# Security policy

## Supported versions

Security fixes are made in the latest release only. Upgrade by running the install command again:

```sh
curl -fsSL https://raw.githubusercontent.com/datashard-ai/gh0stwriter/main/install.sh | sh
```

## Reporting a vulnerability

Please report security problems privately, through GitHub:
[report a vulnerability](https://github.com/datashard-ai/gh0stwriter/security/advisories/new).
Don't open a public issue.

Please include:

- the gh0stwriter version (`gh0stwriter --version`) and your macOS version;
- what an attacker could do, and what they would need;
- the steps to reproduce it.

We will acknowledge your report, keep you informed as we investigate, and credit you in the release
notes unless you'd rather not be named.

## Scope

In scope: the `gh0stwriter` binary, its install script, and the files it writes in `~/gh0stwriter`
(or `GH0STWRITER_HOME`) and `~/.config/gh0stwriter`.

Out of scope: sox, AssemblyAI and their services, which have their own security policies.
