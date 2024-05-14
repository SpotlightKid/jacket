import std/[logging, os]
import signal
import jacket

var jclient: ClientP
var status: cint
var exitSignalled: bool = false
var log = newConsoleLogger(when defined(release): lvlInfo else: lvlDebug)

proc cleanup(sig: cint = 0) =
    debug "Cleaning up..."
    if jclient != nil:
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

addHandler(log)
setErrorFunction(errorCb)
jclient = clientOpen("jacket_port_register", NoStartServer or UseExactName, status.addr)
debug "JACK server status: " & $status

if jclient == nil:
    error getJackStatusErrorString(status)
    quit QuitFailure

when defined(windows):
    setSignalProc(signalCb, SIGABRT, SIGINT, SIGTERM)
else:
    setSignalProc(signalCb, SIGABRT, SIGHUP, SIGINT, SIGQUIT, SIGTERM)

discard jclient.portRegister("in_1", JACK_DEFAULT_AUDIO_TYPE, PortIsInput, 0)
discard jclient.portRegister("out_1", JACK_DEFAULT_AUDIO_TYPE, PortIsOutput, 0)

jclient.onShutdown(shutdownCb)

while not exitSignalled:
    sleep(50)

cleanup()
