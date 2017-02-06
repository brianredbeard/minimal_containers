# Building containers with Buildroot

## About

As a user reading this, you've likely watched the presentation linked in the
[README.md] file and thus know that the primary mechanism I use for building
containers is with [Buildroot](https://buildroot.org). In truth, the way I am
using Buildroot is an abuse of what it is designed for (building embedded Linux
distributions).  It's coincidental that all of the things I _desire_ in building
a container are congruent with the design of an embedded system:

  - ability to choose init system (or *lack* of one in our case)
  - no documentation (in the container, e.g. `man`/info pages, etc)
  - ability to easily build without LOCALES
  - etc

Buildroot even goes farther and let's me build everything _without a kernel_.

In order to facilitate people getting started with this, I have added this
getting started guide to provide a practical tutorial.

In this tutorial I'm going to build a container for the server component of the
task management software "[Taskwarrior](https://taskwarrior.org/)".
Taskwarrior is a command line task mangement tool that embodies many of the
computing theories that are near and dear to my heart, namely free/libre open
source software and the "UNIX™" methodology (do one thing, do it well, and make
it easy to interoperate with other tools.)  

These directions are not meant to be exhastive, but merely a walk through of my
process for getting things done with some tips and tricks along the way.

## Getting started

To get started, first one needs to identify their build environment.
Personally, I use a Linux laptop (and desktop) which makes this process simple
to both get started and track changes.  Users on a Apple or Windows based
operating system will likely benefit from using a virtual machine.  Recently to
facilitate this, Buildroot has begun publishing a
[Vagrantfile](https://buildroot.org/downloads/Vagrantfile).  

We will be making a number of changes which we will want to keep in revision
control.  As such, we will use two git repositories.  One for the upstream
buildroot and one for our changes.  A sample repository of (some) of my changes
can be seen at https://github.com/brianredbeard/coreos_buildroot.  The original
source documentation on this process can be found at
https://buildroot.org/downloads/manual/manual.html#outside-br-custom and will
always be correct for the current stable version.  The honest truth is that
documentation drift is a real thing, and this document may not be up to date as
the purpose is general guidance.

Make a directory to hold all of our changes (`~/Projects`) and a subdirectory
where we will create our git repo:

```
$ mkdir -p ~/Projects/local_buildroot
```

Perform a clone of Buildroot (`NOTE`: I do this because I often want the up
to date versions of software.  If you decide that you want to use one of the
Buildroot stable releases you may always download it from
https://buildroot.org/downloads, or simply check out the tag for the release you
wish to use, e.g. `git checkout 2016.11`).

```
$ cd ~/Projects
$ git clone git://git.buildroot.net/buildroot
```

Now we will create our repository to store local changes.  This is just an
ordinary git repository with a well structured pattern as per the "Keeping
customizations outside of Buildroot" as noted above.

```
$ cd local_buildroot
$ git init
$ mkdir configs package
```

The true "magic" comes in when we add some metadata files which then allow
Buildroot to parse/discover everything in this directory as if it were a part of
the upstream tree.  This requires three files at a minimum:

  * `external.desc` - This is a metadata file which identifies your local tree
    and allows for the use of multiple concurrent external trees by having
    unique identifiers. At a minimum you will need key called "name".
  * `external.mk` - This is a makefile which will include other makefiles at
    well defined paths, such as our packages.
  * `Config.in` - This is a `[Kconfig](https://www.kernel.org/doc/Documentation/kbuild/kconfig-language.txt)`
    syntax file which provides the menuing system which we will see later when
    configuring our environment.

In this snippet we have chosen the name "LOCAL_BUILDROOT" as the name of our
external tree.  This choice is at the whimsy of the operator and could have just
as easily been `FOO` or `MONKEYS`.  Save yourself a headache and just
standardize on the uppercase version. ;)

```
$ echo 'name: LOCAL_BUILDROOT' > external.desc
$ echo 'include $(sort $(wildcard $(BR2_EXTERNAL_LOCAL_BUILDROOT_PATH)/package/*/*.mk))' > external.mk
$ echo 'source "$BR2_EXTERNAL_LOCAL_BUILDROOT_PATH/package/Config.in"' > Config.in
```
Through the definition of our `NAME` above, we now have a number of variables
which will be exposed to us in our makefiles like
`BR2_EXTERNAL_LOCAL_BUILDROOT_PATH` above. This is helpful because it means we
can achieve a high degree of configuration later.

At this point we now have everything defined for our local copy.  Commit
everything to revision control:

```
$ git add *
$ git commit
```

## Customizing our build

### Quick anecdote
Let me start with an anecdote.  Right after starting at CoreOS (March, 2014) all
of us went on a trip to Lake Tahoe, CA, USA.  We locked ourselves in a house for
a week and worked on a bunch of things to make Container Linux (née CoreOS
Linux) ready for a wider audience.  This included the creation of
`coreos-cloudinit`, changes to the `usr` partition structure, early work on
GRUB, and others.  A bunch of "friends of the core" joined us, including [Greg
KH](https://en.wikipedia.org/wiki/Greg_Kroah-Hartman), the maintainer of the
`stable` Linux kernel branch.

I remember being very nervous at one point because Greg was shoulder surfing me
while I was configuring a kernel (I was doing one of our early passes on the
inclusion of SELinux).  As I come from a background of systems administration
type work, I began configuring the kernel as I assumed all gods and men before
me had: using `vi`.  It was at this point I hear the baritone voice of Greg
behind me asking in a confused tone:

  "Redbeard... what are you doing?"

I freeze.  I have been working with Linux professionally for almost 15 years at
this point.  I've been compiling kernels since my days as a Slackware user in
the 90s.  I have obviously commited some egregious sin to have Greg stopping me.
That being said, any sage wisdom is always accepted.  It's at this point that I
explain to him what I'm doing.  He responds:

  "Why aren't you using the menu system?"

I'm astounded.  MENU system?!  What kind of insult is this?  I am a
professional!  I started using vi because when troubleshooting a system it would
fit on a 3½" floppy disk, so I knew I would not have a hacked binary or
corrupted editor for disaster recovery.  _*I*_ do not _need_ a menu system!

Greg continues, "I use the menu system all the time.  It *just works* for
handling dependency management and we spent a bunch of time both making sure we
got it right _AND_ keeping all of the definitions up to date... Just use it."

A great weight was lifted from my shoulders.  There was an entire set of
knowledge that could now be freed up (tracking all of this depenency management
in my head) leaving more active memory for other processes.  The take away here
is this.  Work smart, not hard.  You're not going to win a pissing contest by
doing extra work.  Thus... we move into actually using this system...

### Configuring your build

Buildroot contains a series of configuration files in Kconfig format (mentioned
above).  As we have a linked series of Kconfigs we can use all of the normal
tools available to one for the configuration of a kernel.  In our case we're
going to focus on using a text user interface as it works great over SSH though
you could use others as well, like `make gconfig`.

To start, we will:
  - change back to our buildroot directory
  - set our `BR2_EXTERNAL` environment variable
  - begin the configuration process

```
$ cd ~/Projects/buildroot
$ export BR2_EXTERNAL=${HOME}/Projects/local_buildroot
$ make menuconfig
```

The process of setting that environment variable only needs to be done once.
After it is set and a `make` process is run, it will create a new hidden file
located at `~/Projects/buildroot/output/.br-external.mk`.  Once this file is in
place, all of the configurations found in `~/Projects/local_buildoot` should be
discovered.  If you decide to change your external configuration (or remove it,
but keep Buildroot), just remove this file and Buildroot will no longer try to
reference that path.

There are other less verbose ways of doing this, but this process was chosen as
it should be very clear to all Linux users that an ordinary environment variable
is being used.

Once `make menuconfig` is started you should see a window as follows:

![buildroot screenshot](/images/make_menuconfig_main.png)

Within this menu, if `BR2_EXTERNAL` was set, you should see an option at the
bottom of "`External options --->`".

#### Target Options / Architecture 

The first step in building our container is to define the "architecture", for
99.9% of users reading this document that will be `x86_64`.  The nice thing
about this though is that you are not beholden to building just for x86_64.  If
you're one of the emerging containerization users on an ARM chipset, you can
easily build the exact environment that you need.  

To select `x86_64` as our architecture, select "`Target Options`", then
"`Architecture`".  Choose `x86_64` from the list and then press "enter."

When you select this, you will find the option "`Target Architecture Variant`"
change to the value "`(nocona)`".  Think of this as the "lowest common
denominator" on the _version_ or _features_ available on the CPUs you wish to
use.  In general `nocona` is a safe bet, but this also means you can tune the
compiling for more modern hardware and get even more performance (or features)
out of your applications.  For example when selecting `nocona` Buildroot will
then make the following requirements on your behalf:

  - `BR2_X86_CPU_HAS_MMX=y`
  - `BR2_X86_CPU_HAS_SSE=y`
  - `BR2_X86_CPU_HAS_SSE2=y`
  - `BR2_X86_CPU_HAS_SSE3=y`

While selecting `corei7` will present the following:

  - `BR2_X86_CPU_HAS_MMX=y`
  - `BR2_X86_CPU_HAS_SSE=y`
  - `BR2_X86_CPU_HAS_SSE2=y`
  - `BR2_X86_CPU_HAS_SSE3=y`
  - `BR2_X86_CPU_HAS_SSSE3=n`
  - `BR2_X86_CPU_HAS_SSE4=n`
  - `BR2_X86_CPU_HAS_SSE42=n`

At first glance, these seem the same.  Both are setting the "yes" options on the
Streaming SIMD Extensions for version 1, 2, & 3.  You will notice though that
they also provide _additional_ options (which default to "no") when selecting
`corei7`.  That's because these options are never available on nocona or earlier
chips, while (for example) if you have a Nahelem (or later) chipset you can add
support for additional assembly instruction sets merely by toggling a flag.

This is fantastic because most organizations are running relatively new
hardware (Nahelem was _released_ in 2008 and _replaced_ in 2011) but "advanced"
instruction sets are often not enabled in order to guarantee execution on the
most number of systems possible.  Think about it... now you have the capability
of squeezing even more performance out of your applications, merely with
configuration options.

When you're done in this menu press `esc` to go back to the previous menu.

#### Build options

In this section, I prefer to enable the compiler cache, stack smashing protection,
and having the system use relative paths.  Select each of these options and hit
enter.  In the case of stack smashing protection, you will need to choose a type
of "`-fstack-protector-strong`".

#### Toolchain

The toolchain section allows us to tweak what is used to build all of the
components of our container/system.  This means you can select things down to
the level of the C library to be used, the Linux kernel application binary
interface version, or even use a completely external toolchain.

Change the C library to `glibc`, select your kernel headers version (note:  This
effectively says that you will never try to run this application on a kernel
_older_ than the one you select.  Thus, if you're building a container to run
atop a system like CentOS 7, they will *NEVER* use a kernel newer than 3.10).
In general, it's easy enough to play it safe and choose 3.4.x if you plan to run
atop CentOS/RHEL 7 or a 4.x version if utilizing CoreOS).

I enable C++ support, as it's required for IPv6 support.

#### System configuration

On the "System configuration" screen we want to first and foremost disable the
init system.  We're only going to run a single process, so there is no point in
including things we won't use.  Additionally, some users will want to change
the shell that is used.  By default it will be `/bin/ash`, the shell provided by
Busybox.  Users can also enable bash, but that can be a little bit of a dance
(plus... do you _really_ need full bash?  There are cases where I do, but let's
not have another shellshock on our hands.)

I also like to check "Purge unwanted locales" and set my list of locales to "C
POSIX".  Might as well uncheck "Enable root login with password" too.

#### Kernel

Uncheck it and move on.  :)  Since this is a container we already have a
running kernel.

#### Target packages

This is where things get fun.  This is where we are going to enable `taskd`, the
Taskwarrior server.  First though, rather than trying to find it, let's do a
search, so in the window type `/` to pull up the search dialog then enter
`taskd` and hit enter.

Voila.  We see that `taskd` can be enabled under "`Target packages`" ->
"`Miscellaneous`".

Go select that package, and when done hit `esc` to go to the main menu, then
using the arrow keys navivate to `Save` and save the config as the name
`.config`.  After doing this, exit.


### Compiling your container

This is the hardest part of the whole process, largely because it's the
impatience of waiting.  Run the following command:

```
$ make
```

That's it.  You're done.  When the build is done, you will see no more messages
to standard out and line that says the following:

`/usr/bin/install -m 0644 support/misc/target-dir-warning.txt
/home/bharrington/Projects/buildroot/output/target/THIS_IS_NOT_YOUR_ROOT_FILESYSTEM`

At this point, the tarball of your filesystem has been created and is located at
the following path:

`~/Projects/buildroot/output/images/rootfs.tar`

### Importing your container to Docker

Sweet!  We have a container filesystem ready to go, now let's import it into
Docker and check it out:

```
$ docker import output/images/rootfs.tar taskd
sha256:61b7638dc754342b3307d2c0629a7ceee5ae9a99daac6f013265aa7eb67a2a40
```

Now that it's in our local Docker repo we can try running it:

```
$ docker run -ti -u 1000:1000 taskd /bin/ash
/ $ 
```

### Creating a useful Dockerfile
Great! We were able to get a prompt, now let's see how everything looks:

```
/ $ mkdir /tmp/taskdata
/ $ export TASKDDATA=/tmp/taskddata
/ $ taskd init
You must specify the 'server' variable before attempting a server start, for
example:
  taskd config server localhost:53589

Created /tmp/taskddata/config
/tmp $ taskd config server localhost:53589
Config file /tmp/taskddata/config modified.
/tmp $ taskd config log -
Config file /tmp/taskddata/config modified.
```

Seems like things are working well enough that I'm able to create a
configuration.  Let's try to start it:

```
/tmp $ taskd server 
2017-02-06 18:44:26 ==== taskd 1.1.0  ====
2017-02-06 18:44:26 Serving from /tmp/taskddata
2017-02-06 18:44:26 Using address localhost
2017-02-06 18:44:26 Using port 53589
2017-02-06 18:44:26 Using family 
2017-02-06 18:44:26 Queue size 10 requests
2017-02-06 18:44:26 Request size limit 1048576 bytes
2017-02-06 18:44:26 IP logging on
2017-02-06 18:44:26 Certificate 
2017-02-06 18:44:26 Server Certificate not readable: ''
/tmp $ 
```

Ok, so it looks like we'll need to note a few things to plan our container a bit
further:

  # Where do we want to store files inside of the container?
  # What port do we want to listen on?
  # What do we do about SSL certs?

Well, frankly put the first two are simple decisions the certificate management
is a bit outside the scope of building a container anyways, so let's just make
some decisions and keep things rolling.

Let's use the values from the `Taskserver` documentation:

  - Port number: 53589
  - Data path: `/var/taskwarrior` (though I'm a little more partial to
    `/var/lib/taskwarrior` as it follows a little closer to the filesystem
hierarchy standard - `man hier` / http://www.pathname.com/fhs/)

As we've come to some decisions we can start making our Dockerfile:

```
FROM taskd

# Set a default port, so we can predictable know what to publish
EXPOSE 53589

# Create a directory to hold our data, and make sure it's writable by the
# non-root user under which we will run taskd
RUN mkdir /var/taskwarrior 
RUN chown 1000:1000 /var/taskwarrior 

# Flag this location as a place we will store state
VOLUME /var/taskwarrior

# Set the TASKDDATA environment variable so taskd will always have it available
ENV TASKDDATA=/var/taskwarrior

# Specify that we should always run as UID/GID 1000
USER 1000:1000

# The default command to be run, any arguments to the container will always be
# to this command
ENTRYPOINT ["/usr/bin/taskd"]

# The default argument we will use when none are provided
CMD ["server"]

```

Finally, let's take this and use it:

```
$ docker build  --no-cache  -t taskd:v1.1.0 .
Sending build context to Docker daemon 2.048 kB
Step 1 : FROM taskd
 ---> 61b7638dc754
Step 2 : EXPOSE 53589
 ---> Running in ef35fcc5251a
 ---> 246dda00cadd
Removing intermediate container ef35fcc5251a
Step 3 : RUN mkdir /var/taskwarrior
 ---> Running in 296ea1875613
 ---> f3a519c7018c
Removing intermediate container 296ea1875613
Step 4 : RUN chown 1000:1000 /var/taskwarrior
 ---> Running in fbfa7ce06574
 ---> afb38e59f206
Removing intermediate container fbfa7ce06574
Step 5 : VOLUME /var/taskwarrior
 ---> Running in e178b00bef90
 ---> bc0d0a572fc7
Removing intermediate container e178b00bef90
Step 6 : ENV TASKDDATA /var/taskwarrior
 ---> Running in 04d77bbc7b82
 ---> 017408950a47
Removing intermediate container 04d77bbc7b82
Step 7 : USER 1000:1000
 ---> Running in 3cb2053e62fd
 ---> 821a2a25a5b4
Removing intermediate container 3cb2053e62fd
Step 8 : ENTRYPOINT /usr/bin/taskd
 ---> Running in da869261e051
 ---> 74044abb1ab6
Removing intermediate container da869261e051
Step 9 : CMD server
 ---> Running in 5575a60f4ab2
 ---> 460efd827d14
Removing intermediate container 5575a60f4ab2
Successfully built 460efd827d14
```

And, let's see how we did:
```
$ docker images taskd:v1.1.0
REPOSITORY      TAG           IMAGE ID          CREATED          SIZE
taskd           v1.1.0        460efd827d14      42 seconds ago   12.25 MB
``
Looking good at 12.25MB.`

### Getting started with our container

Now that we have our binaries let's try things out.  First we'll need to create
a place to store our data/configuration.  I'm pretty partial to bind mounts, so
let's create a temporary directory to use:

```
$ mktemp -d 
/tmp/tmp.VGjHKxakYm
```

Now, let's use that directory with taskd:

```
$ docker run -ti -v /tmp/tmp.VGjHKxakYm:/var/taskwarrior taskd:v1.1.0 init
You must specify the 'server' variable before attempting a server start, for
example:
  taskd config server localhost:53589

Created /var/taskwarrior/config
$ ls -l /tmp/tmp.VGjHKxakYm
total 4
-rw-------. 1 bharrington bharrington 187 Feb  6 11:12 config
drwx------. 2 bharrington bharrington  40 Feb  6 11:12 orgs
```

Everything is continuing to look good, now lets set our various configuration
options:

```
$ docker run -ti -v /tmp/tmp.VGjHKxakYm:/var/taskwarrior taskd:v1.1.0 config server localhost:53589
Config file /var/taskwarrior/config modified.
$ docker run -ti -v /tmp/tmp.VGjHKxakYm:/var/taskwarrior taskd:v1.1.0 config log -
Config file /var/taskwarrior/config modified.
$ cat /tmp/tmp.VGjHKxakYm/config 
confirmation=1
extensions=/usr/libexec/taskd
ip.log=on
log=-
pid.file=/tmp/taskd.pid
queue.size=10
request.limit=1048576
root=/var/taskwarrior
server=localhost:53589
trust=strict
verbose=1

```

As you can see, if we had an existing set of configurations we would be able to
just drop them in and go.

# vim: set ts=2 sw=2 expandtab textwidth=80:
