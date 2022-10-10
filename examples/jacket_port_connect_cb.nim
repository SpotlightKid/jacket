import std/[logging, os]
import jacket
import signal

var jclient: ClientTPtr
var status: cint
var exitSignalled: bool = false
var log = newConsoleLogger(when defined(release): lvlInfo else: lvlDebug)

proc cleanup(sig: cint = 0) =
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
    info "Received signal: " & $sig
    exitSignalled = true

proc shutdownCb(arg: pointer = nil) {.cdecl.} =
    info "JACK server has shut down."
    exitSignalled = true

proc portConnected(portA: PortIdT; portB: PortIdT; connect: cint; arg: pointer) {.cdecl.} =
    let portAPtr = jclient.portById(portA)
    let portBPtr = jclient.portById(portB)
    
    if portAPtr != nil:
        echo("Port A: ", portName(portAPtr))
    else:
        echo "Port A: <unknown>"

    if portAPtr != nil:
        echo("Port B: ", portName(portBPtr))
    else:
        echo "Port B: <unknown>"
        
    echo("Action: ", if connect > 0: "connect" else: "disconnect")

addHandler(log)
setErrorFunction(errorCb)
jclient = clientOpen("jacket_port_connect_cb", NoStartServer.ord, status.addr)
debug "JACK server status: " & $status

if jclient == nil:
    error getJackStatusErrorString(status)
    quit QuitFailure

when defined(windows):
    setSignalProc(signalCb, SIGABRT, SIGINT, SIGTERM)
else:
    setSignalProc(signalCb, SIGABRT, SIGHUP, SIGINT, SIGQUIT, SIGTERM)

discard jclient.portRegister("in_1", JACK_DEFAULT_AUDIO_TYPE, PortIsInput.ord, 0)
discard jclient.portRegister("out_1", JACK_DEFAULT_AUDIO_TYPE, PortIsOutput.ord, 0)

if jclient.setPortConnectCallback(portConnected, nil) != 0:
    error "Error: could not set JACK port connection callback."

jclient.onShutdown(shutdownCb, nil)

if jclient.activate() == 0:
    while not exitSignalled:
        sleep(50)

cleanup()
