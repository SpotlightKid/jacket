import std/logging
import jacket

var status: cint
var log = newConsoleLogger(when defined(release): lvlInfo else: lvlDebug)

proc errorCb(msg: cstring) {.cdecl.} =
    # Suppress verbose JACK error messages when server is not available by
    # default. Pass ``lvlAll`` when creating the logger to enable them.
    debug "JACK error: " & $msg

addHandler(log)
setErrorFunction(errorCb)
var jclient = clientOpen("jacket_info", NullOption, status.addr)
debug "JACK server status: " & $status

if jclient == nil:
    error getJackStatusErrorString(status)
    quit 1

echo("JACK version: ", getVersionString())
echo("Sample rate: ", jclient.getSampleRate)
echo("Buffer size: ", jclient.getBufferSize)
echo("RT enabled: ", if jclient.isRealtime > 0: "yes" else: "no")
echo("DSP load: ", jclient.cpuLoad, "%")
echo("Server time: ", getTime())
echo("Client name: ", jclient.getClientName)

jclient.clientClose()
