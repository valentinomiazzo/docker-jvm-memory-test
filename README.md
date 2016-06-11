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
If you leave the container run for some seconds you will see that it will exit when it will be killed by Docker.

# Simulate another memory leak on the heap
This is like before except:
- the JVM will give an OutOfMemoryException at 32MB
```sh
$ docker run -it --memory=64m --memory-swap=64m --env ALLOC_HEAP_MB=1 --env MAX_HEAP_SIZE_MB=32 valentinomiazzo/jvm-memory-test
```
In this case, as expected, we get an OutOfMemoryException. This kills the Java application that exits and the same happens to the container.

# Supported leaks
The image supports the following types of leaks. See the Dockerfile for details about all the available enviroment variables.
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
