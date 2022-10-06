import std/[strformat, os]

import jacket

var client: ClientTPtr
var status: cint

proc cleanup() {.noconv.} =
    echo "Cleaning up..."
    if client != nil:
        discard clientClose(client)
        client = nil
    quit 0


client = clientOpen("jacket_port_register", ord(NoStartServer) or ord(UseExactName), addr status)

echo fmt"Server status: {status}"

if client == nil:
    echo getJackStatusErrorString(status)
    quit 1

setControlCHook(cleanup)

discard portRegister(client, "in_1", JACK_DEFAULT_AUDIO_TYPE, ord(PortIsInput), 0)
discard portRegister(client, "out_1", JACK_DEFAULT_AUDIO_TYPE, ord(PortIsOutput), 0)

while true:
    sleep(50)

cleanup()
