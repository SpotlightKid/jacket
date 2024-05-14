import std/[logging, os, strutils]
import signal
import jacket

var
    jclient: ClientP
    event: MidiEvent
    midiPort: PortP
    midiEventChan: Channel[MidiEvent]
    midiEventPrinter: Thread[void]
    status: cint
    exitSignalled: bool = false

var log = newConsoleLogger(when defined(release): lvlInfo else: lvlDebug)


proc cleanup() =
    debug "Cleaning up..."

    if jclient != nil:
        debug "Deactivating JACK client..."
        discard jclient.deactivate()

    if midiEventPrinter.running:
        debug "Stopping MIDI event printer thread..."
        # Receiving an invalid event causes receiving thread to wake up and
        # break its endless loop
        event.size = 0
        midiEventChan.send(event)

    midiEventPrinter.joinThread()

    debug "Closing MIDI event channel..."
    midiEventChan.close()

    if jclient != nil:
        debug "Closing JACK client..."
        discard jclient.clientClose()
        jclient = nil

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

proc midiEventPrinterProc() =
    var event: MidiEvent

    while true:
        event = midiEventChan.recv()

        if event.size == 0:
            break
        elif event.size <= 3:
            for i in 0..<event.size:
                stdout.write(event.buffer[i].toHex)
                stdout.write("h ")

            stdout.write("\n")
            stdout.flushFile()

proc processCb*(nFrames: NFrames, arg: pointer): cint {.cdecl.} =
    let inbuf = portGetBuffer(midiPort, nFrames)
    let count = midiGetEventCount(inbuf)

    for i in 0..<count:
        if midiEventGet(event.addr, inbuf, i.uint32) == 0:
            if not midiEventChan.trySend(event):
                warn "MIDI event channel overflow!"

proc main() =
    addHandler(log)

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
    # Channel and prints them without danger of blocking the process callback
    midiEventChan.open()
    createThread(midiEventPrinter, midiEventPrinterProc)

    # Register JACK callbacks
    if jclient.setProcessCallback(processCb) != 0:
        error "Could not set JACK process callback function."
        cleanup()
        quit QuitFailure

    jclient.onShutdown(shutdownCb)

    # Create output port
    midiPort = jclient.portRegister("midi_in", JACK_DEFAULT_MIDI_TYPE, PortIsInput, 0)

    # Activate JACK client ...
    if jclient.activate() == 0:
        # ... and keep running until a signal is received
        while not exitSignalled:
            sleep(200)

    cleanup()


when isMainModule:
    main()
