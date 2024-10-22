# Minimal Containers 101

## About

This presentation is a primer on the process of building minimal Linux
containers.  These directions should be taken with a grain of salt.

As mentioned (verbally) in the presentation, these directions are not for
everyone.  While most folks involved with Linux will learn a thing or two about
the mechanisms used for containerization, these directions are for the folks
who wish to curate the content of their containers.

Within this repository you'll find the original slides in Libre Office Impress
"ODP" format.  This is the canonical presentation.  There is also a copy of the
presentation rendered into PDF for those who do not have access(?) to
Libre Office.

This process began simply.  The `busybox` image curated by Docker Inc is
built using µLibC.  While this may be sufficient for many users, it was
insufficient for the author.  This required finding a different process for
building a busybox image, only using GLIBC.  Enter "Buildroot".

When this talk was first done (München, 2015-02-03) there was very little in
the way of documentation around this process.  Back in June of 2015 Docker began
providing documentation around doing [this](https://github.com/docker/docker/blob/master/docs/userguide/eng-image/baseimages.md)
(note: URL updated as the original file moved and seems to have been re-written).

The video for the presentation can be found here: [Getting weird with containers](https://www.youtube.com/watch?v=gMpldbcMHuI)

## Basic Concept

The basic principal is that you're creating a "chroot" filesystem which will be
put into a "tape archive" file ([TAR](https://en.wikipedia.org/wiki/Tar_(computing))).
Once the tar file is created it can be consumed by your containerization system
of choice.

## Using the images

### [Docker](https://www.docker.com) 

Docker is a Linux containerization system written in Golang with a focus on a
easy to use development experience.  The proccess for importing a tar image
into docker is as simple as:

```
$ cat image.tar | docker import - tagname
```

At this point the user has a complete image.  While there is no metadata
attached to the image, it can still be run as one would expect, simply add a
command:

```
$ docker run -t -i tagname /bin/sh
```

While a user can attach a `Dockerfile` using the option `-c`, it's the opinion
of the author that it's easier to follow the process in a step by step fashion.

Using the previously created docker image (tagged `tagname`) we would produce
the following `Dockerfile`:

```
FROM tagname

CMD ["/bin/sh"]
```

After this step is performed, run the command:

```
$ docker build . tagname:v1.0
```

At this point the image is ready to be used.


### [ACI](https://github.com/appc/spec)

The process for generating an ACI from a derived rootfs can be done in a number
of ways.  Most users will find it easiest to use the utility [`acbuild`]
(https://github.com/appc/acbuild).  This utility emulates the step by step
nature of a Dockerfile.  One issue with `acbuild` is it's heavy use of operator
privileged permissions.  Most users will find that they need to repeatedly 
"`sudo`" various commands in order to do useful work.  It's important to note
that this is related to `acbuild` and not ACI images in general.

As an example of this there is the utility `scripts/gentoo-stage3-aci.sh` which
users may use to generate an ACI image out of the current autobuild of the
Gentoo stage 3 image.  As this is a toolkit used for compiling operating systems
it can be especially useful for automated compiles.  This image is used to build
base containers with Buildroot so as to have a consistent development
environment.

#### scripts/gentoo-stage3-aci.sh example:

It should be noted that the errors coming from attempted `mknod` commands are
not a problem for users running containerized workloads as these special/block
files are already handled by the containerization engine.


```
$  ./gentoo-stage3-aci.sh 
gpg: requesting key F6CD6C97 from hkp server keys.gnupg.net
gpg: key F6CD6C97: "Gentoo-keys Team <gkeys@gentoo.org>" not changed
gpg: Total number processed: 1
gpg:              unchanged: 1
gpg: requesting key 2D182910 from hkp server keys.gnupg.net
gpg: key 2D182910: "Gentoo Linux Release Engineering (Automated Weekly Release Key) <releng@gentoo.org>" not changed
gpg: Total number processed: 1
gpg:              unchanged: 1
Downloading Gentoo Stage 3 (stage3-amd64-20160428.tar.bz2)
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100  238M  100  238M    0     0  13.3M      0  0:00:17  0:00:17 --:--:-- 12.0M
Downloading Gentoo digests
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   720  100   720    0     0   3133      0 --:--:-- --:--:-- --:--:--  3157
Downloading Gentoo digests (detached signature)
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100  1588  100  1588    0     0  12107      0 --:--:-- --:--:-- --:--:-- 12215
Validating GPG signatures of digest hashes
gpg: Signature made Fri Apr 29 14:28:46 2016 UTC using RSA key ID 2D182910
gpg: Good signature from "Gentoo Linux Release Engineering (Automated Weekly Release Key) <releng@gentoo.org>" [unknown]
gpg: WARNING: This key is not certified with a trusted signature!
gpg:          There is no indication that the signature belongs to the owner.
Primary key fingerprint: 13EB BDBE DE7A 1277 5DFD  B1BA BB57 2E0E 2D18 2910
Validating SHA512 hashes from GPG signed DIGESTS file
stage3-amd64-20160428.tar.bz2: OK
Creating rootfs
Exploding stage3 to rootfs
tar: ./dev/sdd6: Cannot mknod: Operation not permitted
tar: ./dev/sdc12: Cannot mknod: Operation not permitted
...
...
...
tar: ./dev/sdb2: Cannot mknod: Operation not permitted
tar: ./dev/tty62: Cannot mknod: Operation not permitted
tar: ./dev/hda15: Cannot mknod: Operation not permitted
tar: ./dev/tty42: Cannot mknod: Operation not permitted
tar: ./dev/sda12: Cannot mknod: Operation not permitted
tar: Exiting with failure status due to previous errors
Skipping sync of portage tree. Set environment variable GENTOO_PORTAGE= to a non empty value to sync.
Writing ACI manifest
Building ACI image
Built Image stage3-amd64-20160428.aci
$ sudo rkt run --interactive --insecure-options image --dns 8.8.8.8 --volume output,kind=host,source=/home/core,readOnly=false --mount volume=output,target=/srv stage3-amd64-20160428.aci 
image: using image from local store for image name coreos.com/rkt/stage1-coreos:1.2.1
image: using image from file stage3-amd64-20160428.aci
networking: loading networks from /etc/rkt/net.d
networking: loading network default with type ptp
rkt-623e5da6-7f1b-4252-9acd-33d34cb0b924 / #
```

## Relevant Links

  * [Buildroot](http://www.buildroot.org) - A SDK for building minimal Linux distributions like OpenWRT.
  * [Alpine](https://alpinelinux.org/) - A streamlined Linux distro focused on security, and lightweight footprint.  Compiled using [musl libc](http://www.musl-libc.org/) vs GLIBC.  Quite a bit of work around Alpine has been done by [Jeff Lindsay](https://github.com/progrium).
  * [debootstrap](https://wiki.debian.org/Debootstrap) - A tool to build a Debian system into a subdirectory on a Linux host.
  * [YUM](http://yum.baseurl.org/) / [DNF](http://dnf.baseurl.org/) - Similar principal to debootstrap.  Here are a couple of examples - [Example 1](https://web.archive.org/web/20150514123601/http://prefetch.net/articles/yumchrootlinux.html) & [Example 2](https://web.archive.org/web/20141203222350/http://zaufi.github.io/administration/2014/06/10/howto-make-a-centos-chroot/)
  * [Gentoo](https://www.gentoo.org/downloads/) - You can directly import the Gentoo "Stage 3 Archive" image and work with it.  Emerge packages, do compiles, etc.
