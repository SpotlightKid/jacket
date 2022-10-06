import std/os
import jacket

var jclient: ClientTPtr
var status: cint

proc cleanup() {.noconv.} =
    echo "Cleaning up..."

    if jclient != nil:
        discard deactivate(jclient)
        discard clientClose(jclient)
        jclient = nil

    quit 0

proc portConnected(portA: PortIdT; portB: PortIdT; connect: cint; arg: pointer) {.cdecl.} =
    let portAPtr = portById(jclient, portA)
    let portBPtr = portById(jclient, portB)
    
    if portAPtr != nil:
        echo "Port A: " & $portName(portAPtr)
    else:
        echo "Port A: <unknown>"

    if portAPtr != nil:
        echo "Port B: " & $portName(portBPtr)
    else:
        echo "Port B: <unknown>"
        
    echo "Action: " & (if connect > 0: "connect" else: "disconnect")
    

jclient = clientOpen("jacket_port_register", NoStartServer.ord, addr status)

echo "Server status: " & $status

if jclient == nil:
    echo getJackStatusErrorString(status)
    quit 1

setControlCHook(cleanup)

discard portRegister(jclient, "in_1", JACK_DEFAULT_AUDIO_TYPE, PortIsInput.ord, 0)
discard portRegister(jclient, "out_1", JACK_DEFAULT_AUDIO_TYPE, PortIsOutput.ord, 0)

if setPortConnectCallback(jclient, portConnected, nil) != 0:
    echo "Error: could not set port connection callback."

discard activate(jclient)

while true:
    sleep(50)

cleanup()
