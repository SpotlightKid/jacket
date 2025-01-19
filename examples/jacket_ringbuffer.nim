import std/[logging, strformat]
import jacket

var log = newConsoleLogger(when defined(release): lvlInfo else: lvlDebug)


proc main() =
    addHandler(log)

    let size = 32
    var read, written: int
    var data = [0x64.byte, 0x65, 0x61, 0x64, 0x62, 0x65, 0x65, 0x66]
    var recvBuf: array[8, byte]

    let rb = ringbufferCreate(size.csize_t)
    debug fmt"Created ringbuffer of {size} bytes size."

    doAssert ringbufferReadSpace(rb) == 0

    written = ringbufferWrite(rb, cast[cstring](data.addr), 4).int
    doAssert written == 4
    debug fmt"Written {written} bytes to ringbuffer."

    doAssert ringbufferReadSpace(rb) == 4

    written = ringbufferWrite(rb, cast[cstring](data[4].addr), 4).int
    doAssert written == 4
    debug fmt"Written {written} bytes to ringbuffer."

    doAssert ringbufferReadSpace(rb) == 8

    read = ringbufferRead(rb, cast[cstring](recvBuf.addr), 4).int
    doAssert read == 4
    debug fmt"Read {read} bytes from ringbuffer. Receive buffer: {recvBuf}"

    doAssert ringbufferReadSpace(rb) == 4

    read = ringbufferRead(rb, cast[cstring](recvBuf[4].addr), 4).int
    doAssert read == 4
    debug fmt"Read {read} bytes from ringbuffer. Receive buffer: {recvBuf}"

    doAssert ringbufferReadSpace(rb) == 0

    debug "Freeing ringbuffer memory."
    ringbufferFree(rb)


when(isMainModule):
    main()
