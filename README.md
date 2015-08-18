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
the way of documentation around this process.  Back in June docker began
providing documentation around doing [this](https://github.com/docker/docker/blob/master/docs/articles/baseimages.md).

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

(Needs to be written)

## Relevant Links

  * [Buildroot](http://www.buildroot.org) - A SDK for building minimal Linux distributions like OpenWRT.
  * [Alpine](https://www.alpinelinux.org/) - A streamlined Linux distro focused on security, and lightweight footprint.  Compiled using [musl libc](http://www.musl-libc.org/) vs GLIBC.  Quite a bit of work around Alpine has been done by [Jeff Lindsay](https://github.com/progrium).
  * [debootstrap](https://wiki.debian.org/Debootstrap) - A tool to build a Debian system into a subdirectory on a Linux host.
  * [YUM](http://yum.baseurl.org/) / [DNF](http://dnf.baseurl.org/) - Similar principal to debootstrap.  Here are a couple of examples - [Example 1](https://web.archive.org/web/20150514123601/http://prefetch.net/articles/yumchrootlinux.html) & [Example 2](https://web.archive.org/web/20141203222350/http://zaufi.github.io/administration/2014/06/10/howto-make-a-centos-chroot/)
  * [Gentoo](https://www.gentoo.org/downloads/) - You can directly import the Gentoo "Stage 3 Archive" image and work with it.  Emerge packages, do compiles, etc.
