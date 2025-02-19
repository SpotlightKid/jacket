import std/[logging, strformat]
import jacket

var
    status: cint
    descs: ptr UncheckedArray[DescriptionT]

var log = newConsoleLogger(when defined(release): lvlInfo else: lvlDebug)

proc errorCb(msg: cstring) {.cdecl.} =
    # Suppress verbose JACK error messages when server is not available by
    # default. Pass ``lvlAll`` when creating the logger to enable them.
    debug "JACK error: " & $msg

addHandler(log)
setErrorFunction(errorCb)
let jclient = clientOpen("jacket_property", NullOption, status.addr)
debug "JACK server status: " & $status

if jclient == nil:
    error getJackStatusErrorString(status)
    quit 1

let numDescs = getAllProperties(descs)

if numDescs != -1:
    for i in 0..<numDescs:
        var desc = descs[i]
        echo fmt"Subject: {desc.subject}"

        if desc.property_cnt > 0:
            for p in 0..<desc.property_cnt:
                var prop = desc.properties[p]
                echo fmt"* {prop.key}: {prop.data} (type: {prop.type})"

        echo ""
        freeDescription(desc.addr, 0)

    free(descs)
else:
    error "Could not get properties!"

jclient.clientClose()
