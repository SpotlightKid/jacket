import std/logging
import jacket

var jclient: ClientTPtr
var status: cint
var log = newConsoleLogger(lvlInfo)

proc errorCb(msg: cstring) {.cdecl.} =
    # Suppress verbose JACK error messges when server is not available by 
    # default. Pass ``lvlAll`` when creating the logger to enable them.
    debug "JACK error: " & $msg

addHandler(log)
setErrorFunction(errorCb)
jclient = clientOpen("test_jacket", NullOption.ord, status.addr)
debug "Server status: " & $status

if jclient == nil:
    error getJackStatusErrorString(status)
    quit 1

echo("JACK version: ", getVersionString())
echo("Sample rate: ", jclient.getSampleRate)
echo("Buffer size: ", jclient.getBufferSize)
echo("DSP load: ", jclient.cpuLoad, "%")
echo("Server time: ", getTime())
echo("Client name: ", jclient.getClientName)
echo("RT enabled: ", if jclient.isRealtime > 0: "yes" else: "no")

discard jclient.clientClose
