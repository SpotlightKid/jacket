import std/[logging, os]
import signal
import jacket

var jclient: ClientTPtr
var status: cint
var log = newConsoleLogger(lvlDebug)

proc errorCb(msg: cstring) {.cdecl.} =
    # Suppress verbose JACK error messages when server is not available by
    # default. Pass ``lvlAll`` when creating the logger to enable them.
    debug "JACK error: " & $msg

proc cleanup(sig: cint = 0) {.noconv.} =
    debug "Cleaning up..."
    
    if jclient != nil:
        discard jclient.clientClose
        jclient = nil

    quit QuitSuccess

addHandler(log)
setErrorFunction(errorCb)
jclient = clientOpen("jacket_port_register", NoStartServer.ord or UseExactName.ord, status.addr)
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

while true:
    sleep(50)

cleanup() # normally not reached
