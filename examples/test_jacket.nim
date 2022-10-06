import jacket

var jclient: ClientTPtr
var time: TimeT
var status: cint

jclient = clientOpen("test_jacket", NullOption.ord, addr status)

echo "Server status: " & $status

if jclient == nil:
    echo getJackStatusErrorString(status)
    quit 1

time = getTime()
let ver = getVersionString()
echo "JACK version: " & $ver
let rate = getSampleRate(jclient)
echo "Sample rate: " & $rate
let bufsize = getBufferSize(jclient)
echo "Buffer size: " & $bufsize
let load = cpuLoad(jclient)
echo "DSP load: " & $load & "%"
echo "Server time: " & $time
let name = getClientName(jclient)
echo "Client name: " & $name
let rt = if isRealtime(jclient) > 0: "yes" else: "no"
echo "RT enabled: " & rt

discard clientClose(jclient)
