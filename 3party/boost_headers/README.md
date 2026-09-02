# Boost headers for Organic Maps

The Boost headers that [Organic Maps](https://github.com/organicmaps/organicmaps)
builds against, as a single small repository.

Organic Maps only ever used Boost's headers, but consuming them from upstream
meant checking out the `boostorg/boost` superproject and its ~172 nested
submodules — about 694 MB of working tree and 1.5 GB of Git metadata for every
contributor and every CI job — and then generating `boost/` with
`./bootstrap.sh && ./b2 headers`. This repository holds the generated tree
instead, so `organicmaps` gets it as one ordinary submodule and needs no Boost
build step at all.

## Layout

    boost/            the include tree, byte-for-byte upstream
    LICENSE_1_0.txt   Boost Software License 1.0
    SOURCE_REVISION   the boostorg/boost commit these headers came from

Add the repository root to the include path; `#include <boost/...>` then works
as usual. In Organic Maps it is the `3party/boost_headers` submodule.

## How it is generated

`b2 headers` does not copy anything — it builds `boost/` as a farm of symlinks
into the modular libraries. `Jamroot` defines it as exactly two globs:

```jam
local all-headers =
    [ MATCH .*libs/(.*)/include/boost : [ glob libs/*/include/boost libs/*/*/include/boost ] ] ;
```

So copying those two globs into one directory reproduces the farm byte for byte,
with no Boost bootstrap required. That is all the update script does; see
`tools/unix/update_boost_headers.sh` in the Organic Maps repository.

The full header set is kept deliberately. A trimmed subset cannot be derived
safely: Boost resolves many includes through macros (`#include BOOST_PP_ITERATE()`)
that no scanner can follow, and the reachable set differs per platform and
compiler, so anything smaller risks breaking a build nobody ran locally.

## Updating

Do not edit these files by hand — they are a verbatim copy and any change would
be lost on the next refresh. Run the Organic Maps script, which rewrites the
tree from a chosen upstream tag and records it in `SOURCE_REVISION`:

```bash
tools/unix/update_boost_headers.sh boost-X.Y.Z
```
