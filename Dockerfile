FROM java:8-jdk-alpine

COPY javassist.jar .
COPY MemoryTest.java .

RUN javac -cp javassist.jar MemoryTest.java > /dev/null 2>&1

# Limits the maximum JVM Heap size. An OutOfMemoryException will be generated.
# Observe 'Java Heap' in jcmd output.
ENV MAX_HEAP_SIZE_MB=64

# Limits the maximum JVM Metaspace size. An OutOfMemoryException will be generated.
# Observe 'Class' in jcmd output.
ENV MAX_CLASS_SIZE_MB=64

# Limits the maximum total size of direct buffers allocated by the JVM. An OutOfMemoryException will be generated.
# Observe 'Internal' in jcmd output.
ENV MAX_DIRECT_SIZE_MB=64

# Defines the Stack size of each thread.
# There is no way to force a limit. If you create enough threads you can use all the available memory.
# Observe 'Thread' in jcmd output.
ENV THREAD_STACK_SIZE_KB=256

# Defines the period of an allocation cycle
ENV ALLOC_PERIOD_MS=1000

# MB of Heap to allocate per cycle.
# Uses: byte[]
# Observe 'Java Heap' in jcmd output.
ENV ALLOC_HEAP_MB=0

# Numer of new classes to load per cycle.
# Uses: javassist to synthetize and load new classes on the fly
# Observe 'Class' in jcmd output.
ENV ALLOC_CLASSES_COUNT=0

# MB of direct memory to allocate per cycle.
# Uses: java.nio.ByteBuffer.allocateDirect()
# Observe 'Internal' in jcmd output.
ENV ALLOC_DIRECT_MB=0

# Numer of new thread to create and start per cycle.
# Uses: new Thread(). The thread just sleeps.
# Observe 'Thread' in jcmd output.
ENV ALLOC_THREADS_COUNT=0

# MB of native memory to allocate per cycle.
# Uses: sun.misc.Unsafe.allocateMemory()
# Observe 'Internal' in jcmd output.
ENV ALLOC_NATIVE_MB=0

# Defines the period for the jcmd output
ENV LOG_PERIOD_S=1

CMD java \
     -XX:+UnlockDiagnosticVMOptions -XX:NativeMemoryTracking=summary -XX:+PrintNMTStatistics -XX:-AutoShutdownNMT \
     -Xmx${MAX_HEAP_SIZE_MB}m -Xms1m \
     -Xss${THREAD_STACK_SIZE_KB}k \
     -XX:MaxMetaspaceSize=${MAX_CLASS_SIZE_MB}m \
     -XX:MaxDirectMemorySize=${MAX_DIRECT_SIZE_MB}m \
     -cp javassist.jar:. \
     MemoryTest $ALLOC_PERIOD_MS $ALLOC_HEAP_MB $ALLOC_NATIVE_MB $ALLOC_DIRECT_MB $ALLOC_CLASSES_COUNT $ALLOC_THREADS_COUNT \
     & PID=$! ; while [ -e /proc/$PID ] ; do jcmd $PID VM.native_memory summary scale=MB ; sleep ${LOG_PERIOD_S}s ; done 
