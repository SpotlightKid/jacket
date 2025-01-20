## Simple JACK client, which just passes audio through
## from its single (mono) input to its single (mono) output.

import std/[logging, os]
import signal
import jacket

var
    jclient: Client
    status: cint
    exitSignalled: bool = false
    inpPort, outPort: Port
    log = newConsoleLogger(when defined(release): lvlInfo else: lvlDebug)

type JackBufferP = ptr UncheckedArray[DefaultAudioSample]

proc errorCb(msg: cstring) {.cdecl.} =
    # Suppress verbose JACK error messages when server is not available by
    # default. Compile in non-release mode or pass ``lvlDebug`` or lower
    # when creating the logger above to enable them.
    debug "JACK error: " & $msg

proc cleanup(sig: cint = 0) =
    debug "Cleaning up..."
    if jclient != nil:
        jclient.deactivate()
        jclient.clientClose()
        jclient = nil

proc signalCb(sig: cint) {.noconv.} =
    debug "Received signal: " & $sig
    exitSignalled = true

proc shutdownCb(arg: pointer = nil) {.cdecl.} =
    warn "JACK server has shut down."
    exitSignalled = true

proc processCb(nFrames: NFrames, arg: pointer): cint {.cdecl.} =
    var inpbuf = cast[JackBufferP](portGetBuffer(inpPort, nFrames))
    var outbuf = cast[JackBufferP](portGetBuffer(outPort, nFrames))

    # copy samples from input to output buffer
    for i in 0 ..< nFrames:
        outbuf[i] = inpbuf[i]

addHandler(log)

# Create JACK Client ptr
setErrorFunction(errorCb)
jclient = clientOpen("passthru", NullOption, status.addr)
debug "JACK server status: " & $status

if jclient == nil:
    error getJackStatusErrorString(status)
    quit QuitFailure

# Register audio input and output ports
inpPort = jclient.portRegister("in_1", JackDefaultAudioType, PortIsInput, 0)
outPort = jclient.portRegister("out_1", JackDefaultAudioType, PortIsOutput, 0)

# Register JACK callbacks
jclient.onShutdown(shutdownCb)

if jclient.setProcessCallback(processCb, nil) != 0:
    error "Could not set JACK process callback function."
    cleanup()
    quit QuitFailure

# Handle signals
when defined(windows):
    setSignalProc(signalCb, SIGABRT, SIGINT, SIGTERM)
else:
    setSignalProc(signalCb, SIGABRT, SIGHUP, SIGINT, SIGQUIT, SIGTERM)

# Activate JACK client ...
if jclient.activate() == 0:
    # ... and keep running until a signal is received
    while not exitSignalled:
        sleep(50)

# Deactivate client and close server connection
cleanup()
