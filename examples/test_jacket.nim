import std/strformat

import jacket

var client: ClientTPtr
var time: TimeT
var status: cint

client = clientOpen("test_jacket", ord(NullOption), addr status)

echo fmt"Server status: {status}"

if client == nil:
    echo getJackStatusErrorString(status)
    quit 1

time = getTime()
var ver = getVersionString()
echo fmt"JACK version: {ver}"
var rate = getSampleRate(client)
echo fmt"Sample rate: {rate}"
var bufsize = getBufferSize(client)
echo fmt"Buffer size: {bufsize}"
var load = cpuLoad(client)
echo fmt"DSP load: {load}%"
echo fmt"Server time: {time}"
var name = getClientName(client)
echo fmt"Client name: {name}"
var rt = if isRealtime(client) > 0: "yes" else: "no"
echo fmt"RT enabled: {rt}"

discard clientClose(client)
