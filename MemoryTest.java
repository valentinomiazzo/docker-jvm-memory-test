import java.util.ArrayList;
import sun.misc.Unsafe;
import java.lang.reflect.Field;

public class MemoryTest {

  private static final class DirectByteArray {

    private final long startIndex;
    private final Unsafe unsafe;

    public DirectByteArray(Unsafe u, long size) {
      unsafe = u;
      startIndex = unsafe.allocateMemory(size);
      unsafe.setMemory(startIndex, size, (byte) 0);
    }

    public void setValue(long index, int value) {
      unsafe.putInt(index(index), value);
    }

    public int getValue(long index) {
      return unsafe.getInt(index(index));
    }

    private long index(long offset) {
      return startIndex + offset;
    }

    public void destroy() {
      unsafe.freeMemory(startIndex);
    }
  }

  private final static class Sleeper extends Thread {

      public void run() {
        while (true) {
          try {
            Thread.sleep(1000);
          } catch(InterruptedException e) {
            break;
          }
        }
      }

  }

  private static int generatedClassesCounter = 0;

  private static final Object createClasses(int count) throws Exception {
    javassist.ClassPool cp = javassist.ClassPool.getDefault();
    ArrayList bag = new ArrayList();
    for (int i = 0; i < count+1; i++) {
      Class c = cp.makeClass("test.Generated" + generatedClassesCounter).toClass();
      generatedClassesCounter++;
      bag.add(c);
    }
    return bag;
  }

  private static final Object createThreads(int count) throws Exception {
    ArrayList bag = new ArrayList();
    for (int i = 0; i < count+1; i++) {
      Sleeper s = new Sleeper();
      s.start();
      bag.add(s);
    }
    return bag;
  }

  private static int MB = 1024*1024;

  public static void main(String[] args) throws Exception {
    if (args.length < 6) {
      System.exit(1);
    }
    int deltaTime = Integer.parseInt(args[0]);
    int deltaHeap = Integer.parseInt(args[1]);
    int deltaNative = Integer.parseInt(args[2]);
    int deltaDirect = Integer.parseInt(args[3]);
    int deltaClasses = Integer.parseInt(args[4]);
    int deltaThreads = Integer.parseInt(args[5]);

    ArrayList bagOfStuff = new ArrayList();

    Field theUnsafe = Unsafe.class.getDeclaredField("theUnsafe");
    theUnsafe.setAccessible(true);
    Unsafe unsafe = (Unsafe) theUnsafe.get(null);

    while (true) {
      if (deltaHeap > 0)   { bagOfStuff.add( new byte[ deltaHeap * MB ] ); }
      if (deltaNative > 0) {
        DirectByteArray dba = new DirectByteArray( unsafe, deltaNative * MB );
        bagOfStuff.add(dba);
      }
      if (deltaDirect > 0) { bagOfStuff.add( java.nio.ByteBuffer.allocateDirect( deltaDirect * MB) ); }
      if (deltaClasses > 0) { bagOfStuff.add( createClasses(deltaClasses) ); }
      if (deltaThreads > 0) { bagOfStuff.add( createThreads(deltaThreads) ); }
      Thread.sleep(deltaTime);
    }
  }
}
