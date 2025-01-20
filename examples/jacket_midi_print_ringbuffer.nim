# This requires either nim 1.9+ or --threads:on:

import std/[locks, logging, os, strformat]
import signal
import jacket

var
    jclient: Client
    event: MidiEventT
    midiPort: Port
    rb: Ringbuffer
    midiEventPrinter: Thread[void]
    status: cint
    exitSignalled: bool = false
    exitLoop: bool = false
    overruns: uint = 0
    dataReady: Cond
    dataReadyLock: Lock

let rbSize = 128

var log = newConsoleLogger(when defined(release): lvlInfo else: lvlDebug)
addHandler(log)

proc cleanup() =
    debug "Cleaning up..."

    if jclient != nil:
        debug "Deactivating JACK client..."
        jclient.deactivate()

    if midiEventPrinter.running:
        debug "Stopping MIDI event printer thread..."
        exitLoop = true
        if dataReadyLock.tryAcquire():
            dataReady.signal()
            dataReadyLock.release()

    debug "Joining MIDI event printer thread..."
    midiEventPrinter.joinThread()
    debug "Joined."

    if jclient != nil:
        debug "Closing JACK client..."
        jclient.clientClose()
        jclient = nil

    debug fmt"Buffer overruns: {overruns}"
    debug "Bye."

proc errorCb(msg: cstring) {.cdecl.} =
    # Suppress verbose JACK error messages when server is not available by
    # default. Pass ``lvlAll`` when creating the logger to enable them.
    debug "JACK error: " & $msg

proc signalCb(sig: cint) {.noconv.} =
    debug "Received signal: " & $sig
    exitSignalled = true

proc shutdownCb(arg: pointer = nil) {.cdecl.} =
    warn "JACK server has shut down."
    exitSignalled = true

proc midiEventPrinterProc() {.thread.} =
    var recvBuf: array[4, uint8]

    dataReadyLock.acquire()

    while true:
        while not exitLoop and ringbufferReadSpace(rb) >= 4:
            discard ringbufferRead(rb, cast[cstring](recvBuf.addr), 4)

            if recvBuf[0] <= 3:
                for i in 0..<recvBuf[0].int:
                    stdout.write(fmt"0x{recvBuf[i+1]:02X} ")

                stdout.write("\n")
                stdout.flushFile()

        if exitLoop:
            break

        dataReady.wait(dataReadyLock)

    dataReadyLock.release()

proc processCb*(nFrames: NFrames, arg: pointer): cint {.cdecl.} =
    var msgBuf: array[4, uint8]

    let inbuf = portGetBuffer(midiPort, nFrames)
    let count = midiGetEventCount(inbuf)

    for i in 0..<count:
        if midiEventGet(event.addr, inbuf, i.uint32) == 0:
            msgBuf[0] = event.size.uint8

            if event.size <= 3:
                for b in 0..<event.size:
                    msgBuf[b+1] = event.buffer[b]

                var written = cast[int](ringbufferWrite(rb, cast[cstring](msgBuf.addr), 4))

                if written < 4:
                    inc(overruns)
                else:
                    if dataReadyLock.tryAcquire():
                        dataReady.signal()
                        dataReadyLock.release()

proc main() =
    # Create JACK client
    setErrorFunction(errorCb)
    jclient = clientOpen("jacket_midi_print", NoStartServer or UseExactName, status.addr)
    debug "JACK server status: " & $status

    if jclient == nil:
        error getJackStatusErrorString(status)
        quit QuitFailure

    # Set up signal handlers to clean up on exit
    when defined(windows):
        setSignalProc(signalCb, SIGABRT, SIGINT, SIGTERM)
    else:
        setSignalProc(signalCb, SIGABRT, SIGHUP, SIGINT, SIGQUIT, SIGTERM)

    # Set up a thread, which receives MIDI events from process callback via a
    # ringbuffer and prints them without danger of blocking the process callback
    rb = ringbufferCreate(rbSize.csize_t)
    debug fmt"Created MIDI ringbuffer of {rbSize} bytes size."
    createThread(midiEventPrinter, midiEventPrinterProc)

    # Register JACK callbacks
    if jclient.setProcessCallback(processCb) != 0:
        error "Could not set JACK process callback function."
        cleanup()
        quit QuitFailure

    jclient.onShutdown(shutdownCb)

    # Create output port
    midiPort = jclient.portRegister("midi_in", JackDefaultMidiType, PortIsInput, 0)

    # Activate JACK client ...
    if jclient.activate() == 0:
        debug "JACK client activated."
        # ... and keep running until a signal is received
        while not exitSignalled:
            sleep(200)

    cleanup()
    debug "Freeing ringbuffer memory."
    ringbufferFree(rb)

when isMainModule:
    main()
