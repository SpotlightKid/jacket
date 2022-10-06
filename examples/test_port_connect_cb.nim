import std/[strformat, os]

import jacket

var client: ClientTPtr
var status: cint

proc cleanup() {.noconv.} =
    echo "Cleaning up..."

    if client != nil:
        discard deactivate(client)
        discard clientClose(client)
        client = nil

    quit 0

proc portConnected(portA: PortIdT; portB: PortIdT; connect: cint; arg: pointer) {.cdecl.} =
    let portAPtr = portById(client, portA)
    let portBPtr = portById(client, portB)
    
    if portAPtr != nil:
        let portAName = portName(portAPtr)
        echo fmt"Port A: {portAName}"
    else:
        echo "Port A: <unknown>"

    if portAPtr != nil:
        let portBName = portName(portBPtr)
        echo fmt"Port B: {portBName}"
    else:
        echo "Port B: <unknown>"
        
    let action = if connect > 0: "connect" else: "disconnect"
    echo fmt"Action: {action}"
    

client = clientOpen("jacket_port_register", ord(NoStartServer) or ord(UseExactName), addr status)

echo fmt"Server status: {status}"

if client == nil:
    echo getJackStatusErrorString(status)
    quit 1

discard portRegister(client, "in_1", JACK_DEFAULT_AUDIO_TYPE, ord(PortIsInput), 0)
discard portRegister(client, "out_1", JACK_DEFAULT_AUDIO_TYPE, ord(PortIsOutput), 0)

if setPortConnectCallback(client, portConnected, nil) != 0:
    echo "Error: could not set port connection callback."

discard activate(client)

while true:
    sleep(50)

cleanup()
