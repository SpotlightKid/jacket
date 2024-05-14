import std/[logging, os, strutils]
import signal
import jacket

var jclient: ClientP
var event: MidiEvent
var midiPort: PortP
var status: cint
var exitSignalled: bool = false
var log = newConsoleLogger(when defined(release): lvlInfo else: lvlDebug)


proc cleanup() =
    debug "Cleaning up..."
    if jclient != nil:
        discard jclient.deactivate()
        discard jclient.clientClose()
        jclient = nil

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

proc printMidiEvent(event: var MidiEvent) =
    if event.size <= 3:
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
            printMidiEvent(event)

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
            sleep(50)

    cleanup()


when isMainModule:
    main()
