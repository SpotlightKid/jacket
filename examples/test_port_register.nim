import std/os
import jacket

var jclient: ClientTPtr
var status: cint

proc cleanup() {.noconv.} =
    echo "Cleaning up..."
    
    if jclient != nil:
        discard clientClose(jclient)
        jclient = nil
    
    quit 0


jclient = clientOpen("jacket_port_register", NoStartServer.ord or UseExactName.ord, addr status)

echo "Server status: " & $status

if jclient == nil:
    echo getJackStatusErrorString(status)
    quit 1

setControlCHook(cleanup)

discard portRegister(jclient, "in_1", JACK_DEFAULT_AUDIO_TYPE, PortIsInput.ord, 0)
discard portRegister(jclient, "out_1", JACK_DEFAULT_AUDIO_TYPE, PortIsOutput.ord, 0)

while true:
    sleep(50)

cleanup()
