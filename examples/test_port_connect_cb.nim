import std/[logging, os]
import jacket
import signal

var jclient: ClientTPtr
var status: cint
var log = newConsoleLogger(lvlDebug)

proc errorCb(msg: cstring) {.cdecl.} =
    # Suppress verbose JACK error messages when server is not available by
    # default. Pass ``lvlAll`` when creating the logger to enable them.
    debug "JACK error: " & $msg

proc cleanup(sig: cint) {.noconv.} =
    debug "Cleaning up..."

    if jclient != nil:
        discard jclient.deactivate()
        discard jclient.clientClose()
        jclient = nil

    quit QuitSuccess

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
jclient = clientOpen("jacket_port_register", NoStartServer.ord, status.addr)
debug "Server status: " & $status

if jclient == nil:
    error getJackStatusErrorString(status)
    quit 1

when defined(windows):
    setSignalProc(cleanup, SIGABRT, SIGINT, SIGTERM)
else:
    setSignalProc(cleanup, SIGABRT, SIGHUP, SIGINT, SIGQUIT, SIGTERM)

discard jclient.portRegister("in_1", JACK_DEFAULT_AUDIO_TYPE, PortIsInput.ord, 0)
discard jclient.portRegister("out_1", JACK_DEFAULT_AUDIO_TYPE, PortIsOutput.ord, 0)

if jclient.setPortConnectCallback(portConnected, nil) != 0:
    error "Error: could not set port connection callback."

if jclient.activate() == 0:
    while true:
        sleep(50)

cleanup()