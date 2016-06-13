# Introduction
This is a Docker image meant to experiment with Docker's resource constraints and the many ways a JVM application can leak memory.

# First run
```sh
$ docker run -it valentinomiazzo/jvm-memory-test
```
It just prints the output of [jcmd](https://docs.oracle.com/javase/8/docs/technotes/guides/troubleshoot/tooldescr006.html) continuosly. Something like:

```
Native Memory Tracking:

Total: reserved=1348MB, committed=17MB
-                 Java Heap (reserved=64MB, committed=2MB)
                            (mmap: reserved=64MB, committed=2MB)

-                     Class (reserved=1032MB, committed=5MB)
                            (classes #414)
                            (mmap: reserved=1032MB, committed=5MB)

-                    Thread (reserved=6MB, committed=6MB)
                            (thread #11)
                            (stack: reserved=6MB, committed=6MB)

-                      Code (reserved=244MB, committed=3MB)
                            (mmap: reserved=244MB, committed=2MB)

-                    Symbol (reserved=1MB, committed=1MB)
                            (malloc=1MB #103)
```

In another shell you can also observer the point of view of Docker and compare it with the one of jcmd. The two are similar but not identical.

```sh
$ docker stats $(docker ps -l -q)
```

Something like:

```
CONTAINER           CPU %               MEM USAGE / LIMIT     MEM %               NET I/O             BLOCK I/O
83c9a5545f48        0.18%               83.47 MB / 134.2 MB   62.19%              648 B / 648 B       0 B / 426 kB
```

# Simulate a memory leak on the heap
In this case we tell to the container:
- to leak 1MB of heap at every cycle (default period 1 second)
- the JVM will give an OutOfMemoryException at 256MB
- the container has max 64MB of RAM assigned ...
- ... and 0MB of swap memory (memory-memory-swap == 0)

```sh
$ docker run -it --memory=64m --memory-swap=64m --env ALLOC_HEAP_MB=1 --env MAX_HEAP_SIZE_MB=256 valentinomiazzo/jvm-memory-test
```

If you leave the container run for some seconds you will see that the container will exit printing something like.

```
Native Memory Tracking:

Total: reserved=1540MB, committed=61MB
-                 Java Heap (reserved=256MB, committed=46MB)
                            (mmap: reserved=256MB, committed=46MB)

-                     Class (reserved=1032MB, committed=5MB)
                            (classes #414)
                            (mmap: reserved=1032MB, committed=5MB)

-                    Thread (reserved=6MB, committed=6MB)
                            (thread #11)
                            (stack: reserved=6MB, committed=6MB)

-                      Code (reserved=244MB, committed=3MB)
                            (mmap: reserved=244MB, committed=2MB)

-                        GC (reserved=1MB, committed=0MB)
                            (mmap: reserved=1MB, committed=0MB)

-                    Symbol (reserved=1MB, committed=1MB)
                            (malloc=1MB #103)

PID   USER     TIME   COMMAND
    1 root       0:00 /bin/sh -c java      -XX:+UnlockDiagnosticVMOptions -XX:NativeMemoryTracking=summary -XX:+PrintNMTStatistics -XX:-AutoShutdownNMT      -Xm
    6 root       0:00 java -XX:+UnlockDiagnosticVMOptions -XX:NativeMemoryTracking=summary -XX:+PrintNMTStatistics -XX:-AutoShutdownNMT -Xmx256m -Xms1m -Xss256k
  318 root       0:00 ps 6
6:
java.io.IOException: Connection refused
	at sun.tools.attach.LinuxVirtualMachine.connect(Native Method)
	at sun.tools.attach.LinuxVirtualMachine.<init>(LinuxVirtualMachine.java:124)
	at sun.tools.attach.LinuxAttachProvider.attachVirtualMachine(LinuxAttachProvider.java:63)
	at com.sun.tools.attach.VirtualMachine.attach(VirtualMachine.java:208)
	at sun.tools.jcmd.JCmd.executeCommandForPid(JCmd.java:147)
	at sun.tools.jcmd.JCmd.main(JCmd.java:131)
```

This is what happened:
- the GC of the JVM tried allocate another chunk of RAM for the Heap
- the cgroup associated with the container went over 64MB of RAM
- the kernel/docker killed the process of the JVM
- the infinite loop calling jcmd was executed yet another time
- the JVM process was not found by the jcmd loop and therefore the CMD completed
- the Docker container exited.

You can check that Docker actually terminated the container with

```sh
$ docker inspect -f '{{json .State}}' $(docker ps -l -q)
{"Status":"exited","Running":false,"Paused":false,"Restarting":false,"OOMKilled":true,"Dead":false,"Pid":0,"ExitCode":0,"Error":"","StartedAt":"2016-06-13T13:33:32.861200851Z","FinishedAt":"2016-06-13T13:33:43.929282195Z"}
```

Note: "OOMKilled":true

# Simulate another memory leak on the heap
This is like before except:
- we limit the JVM to 32MB of Heap (MAX_HEAP_SIZE_MB=32)

```sh
$ docker run -it --memory=64m --memory-swap=64m --env ALLOC_HEAP_MB=1 --env MAX_HEAP_SIZE_MB=32 valentinomiazzo/jvm-memory-test
```

This is the output:

```
Native Memory Tracking:

Total: reserved=1315MB, committed=47MB
-                 Java Heap (reserved=32MB, committed=32MB)
                            (mmap: reserved=32MB, committed=32MB)

-                     Class (reserved=1032MB, committed=5MB)
                            (classes #414)
                            (mmap: reserved=1032MB, committed=5MB)

-                    Thread (reserved=6MB, committed=6MB)
                            (thread #11)
                            (stack: reserved=6MB, committed=6MB)

-                      Code (reserved=244MB, committed=3MB)
                            (mmap: reserved=244MB, committed=2MB)

-                    Symbol (reserved=1MB, committed=1MB)
                            (malloc=1MB #103)

Exception in thread "main" java.lang.OutOfMemoryError: Java heap space
	at MemoryTest.main(MemoryTest.java:92)
```

In this case, as expected, we get an OutOfMemoryException.
This is what happened:
- the GC of the JVM could no allocate another chunk of RAM
- an OutOfMemoryException was thrown and not caught by the main() method
- this caused the exit of the JVM
- the infinite loop calling jcmd was executed yet another time
- the JVM process was not found by the jcmd loop and therefore the CMD completed
- the Docker container exited.

You can check that Docker *didn't* terminate the container with

```sh
$ docker inspect -f '{{json .State}}' $(docker ps -l -q)
{"Status":"exited","Running":false,"Paused":false,"Restarting":false,"OOMKilled":false,"Dead":false,"Pid":0,"ExitCode":0,"Error":"","StartedAt":"2016-06-13T13:39:37.805772027Z","FinishedAt":"2016-06-13T13:40:08.279884682Z"}
```

Note: "OOMKilled":false

# Supported leaks
The image supports the following types of leaks. See the [Dockerfile](Dockerfile) for details about all the available enviroment variables.
- Heap
- Direct buffers
- Native memory via sun.misc.Unsafe.allocateMemory()
- Classes
- Threads

# Build the image

```sh
$ # Let's assume you cloned this repo in jvm-memory-test
$ docker build -t valentinomiazzo/jvm-memory-test jvm-memory-test
```
