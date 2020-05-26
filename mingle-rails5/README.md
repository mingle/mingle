# README

This repository contains code for the re-write of program management portfolio. This has to be used along with main mingle code base.

* How to setup development environment 
    * Install node version manager (nvm)
    * Install node using nvm 
        * `nvm install v8.16.2`
    * Execute `./go` script

## Extra requirement:

Due to possible licensing conflicts, the Oracle Database 11g driver is not bundled with this source code. Download ojdbc6.jar and place it in `vendor/java`. After doing this, the filesystem should look like this:

```
vendor/java/
├── bytelist-1.0.15.jar
├── commons-codec-1.6.jar
├── commons-io-2.2.jar
├── commons-lang-2.4.jar
├── dirgra-0.3.jar
├── invokebinder-1.7.jar
├── jcodings-1.0.18.jar
├── jffi-1.2.16-native.jar
├── jffi-1.2.16.jar
├── jnr-constants-0.9.9.jar
├── jnr-enxio-0.16.jar
├── jnr-netdb-1.1.6.jar
├── jnr-posix-3.0.41.jar
├── jnr-unixsocket-0.17.jar
├── jnr-x86asm-1.0.2.jar
├── joda-time-2.8.2.jar
├── joni-2.1.11.jar
├── jruby-complete-9.1.13.0.jar
├── jruby-rack-1.1.20.jar
├── jzlib-1.1.3.jar
├── log4j-1.2.15.jar
├── nailgun-server-0.9.1.jar
├── ojdbc6.jar
├── options-1.4.jar
├── slf4j-api-1.5.11.jar
├── slf4j-log4j12-1.5.11.jar
└── unsafe-fences-1.0.jar

0 directories, 27 files
```

More details about ojdbc6.jar:

- Repository-Id field in META-INF/MANIFEST.MF in the jar file: JAVAVM_11.2.0.2.0_LINUX_100812.1
- Specification-Vendor field in META-INF/MANIFEST.MF in the jar file: Sun Microsystems Inc.
- SHA 256 sum: a6e151e3c30efbfb3d86ad729dd2f9136a093815baebcfe81e6d0b26893180b2
- File size: 2152051 bytes
- Possible location to get this from: https://www.oracle.com/database/technologies/jdbcdriver-ucp-downloads.html
- The file might be downloaded as `ojdbc6-11.2.0.2.0.jar`, but should be placed on the filesystem as `ojdbc6.jar`.
