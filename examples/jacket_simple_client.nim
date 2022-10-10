import std/[logging, math, os]
import signal
import jacket

var jclient: ClientTPtr
var out1: PortTPtr
var status: cint
var log = newConsoleLogger(when defined(release): lvlInfo else: lvlDebug)

type
    SampleT = DefaultAudioSampleT
    JackBufferPtr = ptr UncheckedArray[SampleT]
const
    tableSize = 4096
    sineFreq = 440.0
    twoPi = Pi * 2.0

type
    SineOsc = object
        waveform: array[0..tableSize, float]
        phase: float
        idxInc: float
    SineOscPtr = ref SineOsc

proc initSineOsc(sr: float, freq: float): SineOsc =
    let phsInc = twoPi / tableSize
    var phase = 0.0
    
    for i in 0 ..< tableSize:
        result.waveform[i] = sin(phase)
        phase += phsInc

    result.phase = 0.0
    result.idxInc = tableSize / sr * freq

proc tick(osc: SineOscPtr): float =
    result = osc.waveform[int(osc.phase)]
    osc.phase += osc.idxInc;
    
    if osc.phase >= tableSize:
        osc.phase -= tableSize

proc errorCb(msg: cstring) {.cdecl.} =
    # Suppress verbose JACK error messages when server is not available by
    # default. Pass ``lvlAll`` when creating the logger to enable them.
    debug "JACK error: " & $msg

proc cleanup(sig: cint = 0) {.noconv.} =
    debug "Cleaning up..."
    
    if jclient != nil:
        discard jclient.deactivate()
        discard jclient.clientClose()
        jclient = nil

    quit QuitSuccess

proc shutdownCb(arg: pointer = nil) {.cdecl.} =
    debug "Server has shut down"
    cleanup()

proc process(nFrames: NFramesT, arg: pointer): cint {.cdecl.} = 
    var outbuf = cast[JackBufferPtr](portGetBuffer(out1, nFrames))
    let osc = cast[SineOscPtr](arg)

    for i in 0 ..< nFrames:
        outbuf[i] = osc.tick() * 0.2

    return 0

addHandler(log)

# create JACK client
setErrorFunction(errorCb)
jclient = clientOpen("jacket_port_register", NoStartServer.ord or UseExactName.ord, status.addr)
debug "Server status: " & $status

if jclient == nil:
    error getJackStatusErrorString(status)
    quit 1

let sampleRate =(float) jclient.getSampleRate()
var osc = initSineOsc(sampleRate, sineFreq)


when defined(windows):
    setSignalProc(cleanup, SIGABRT, SIGINT, SIGTERM)
else:
    setSignalProc(cleanup, SIGABRT, SIGHUP, SIGINT, SIGQUIT, SIGTERM)

if jclient.setProcessCallback(process, osc.addr) != 0:
    error "Could not set process callback function."
    cleanup()

jclient.onShutdown(shutdownCb, nil)

out1 = jclient.portRegister("out_1", JACK_DEFAULT_AUDIO_TYPE, PortIsOutput.ord, 0)

if jclient.activate() == 0:
    #  keep running until the Ctrl+C
    while true:
        sleep(50)

cleanup() # normally not reached
