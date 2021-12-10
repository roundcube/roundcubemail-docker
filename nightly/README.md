# Roundcube Dockerfile for Nightly Builds

The `Dockerfile` in this directory can be used to create nightly builds of Roundcube Webmail from Git master.
It's not recommended to use these builds for productive environments.

Build from this directory with

```
docker build -t roundcubemail:nightly-`date +%Y%m%d` .
```
