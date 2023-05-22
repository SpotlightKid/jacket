import std/[logging, strformat]
import jacket

var
    jclient: ClientP
    status: cint
    pos: Position
    transportState: TransportState

var log = newConsoleLogger(when defined(release): lvlInfo else: lvlDebug)

proc errorCb(msg: cstring) {.cdecl.} =
    # Suppress verbose JACK error messages when server is not available by 
    # default. Pass ``lvlAll`` when creating the logger to enable them.
    debug "JACK error: " & $msg

addHandler(log)
setErrorFunction(errorCb)
jclient = clientOpen("jacket_info", NullOption.ord, status.addr)
debug "JACK server status: " & $status

if jclient == nil:
    error getJackStatusErrorString(status)
    quit 1

transportState = transportQuery(jclient, pos.addr)

echo fmt"usecs: {pos.usecs}"
echo fmt"frameRate: {pos.frameRate}"
echo fmt"frame: {pos.frame}"
echo fmt"valid: {pos.valid.ord}"

if bool(pos.valid.ord and PositionBBT.ord):
    echo fmt"bar: {pos.bar}"
    echo fmt"beat: {pos.beat}"
    echo fmt"tick: {pos.tick}"
    echo fmt"barStartTick: {pos.barStartTick}"
    echo fmt"beatsPerBar: {pos.beatsPerBar}"
    echo fmt"beatType: {pos.beatType}"
    echo fmt"beatsPerMinute: {pos.beatsPerMinute}"

case transportState
of TransportStopped:
    echo "JACK transport stopped, starting it now."
    transportStart(jclient)
of TransportRolling:
    echo "JACK transport rolling, stopping it now."
    transportStop(jclient)
of TransportStarting:
    echo "JACK transport starting, nothing to do."
else:
    echo "Unknown JACK transport state."

discard jclient.clientClose
