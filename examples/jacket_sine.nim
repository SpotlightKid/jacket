import std/[logging, math, os]
import signal
import jacket

var jclient: ClientTPtr
var outPort: PortTPtr
var status: cint
var exitSignalled: bool = false
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

proc cleanup() =
    debug "Cleaning up..."
    if jclient != nil:
        discard jclient.deactivate()
        discard jclient.clientClose()
        jclient = nil

proc errorCb(msg: cstring) {.cdecl.} =
    # Suppress verbose JACK error messages when server is not available by
    # default. Pass ``lvlAll`` when creating the logger to enable them.
    debug "JACK error: " & $msg

proc signalCb(sig: cint) {.noconv.} =
    info "Received signal: " & $sig
    exitSignalled = true

proc shutdownCb(arg: pointer = nil) {.cdecl.} =
    info "JACK server has shut down."
    exitSignalled = true

proc processCb(nFrames: NFramesT, arg: pointer): cint {.cdecl.} = 
    var outbuf = cast[JackBufferPtr](portGetBuffer(outPort, nFrames))
    let osc = cast[SineOscPtr](arg)

    for i in 0 ..< nFrames:
        outbuf[i] = osc.tick() * 0.2

    return 0

addHandler(log)

# Create JACK client
setErrorFunction(errorCb)
jclient = clientOpen("jacket_sine", NoStartServer.ord or UseExactName.ord, status.addr)
debug "JACK server status: " & $status

if jclient == nil:
    error getJackStatusErrorString(status)
    quit QuitFailure

# Create sine oscillator
let sampleRate = jclient.getSampleRate.float
debug "JACK sample rate: " & $sampleRate
var osc = initSineOsc(sampleRate, sineFreq)

# Set up signal handlers to clean up on exit
when defined(windows):
    setSignalProc(signalCb, SIGABRT, SIGINT, SIGTERM)
else:
    setSignalProc(signalCb, SIGABRT, SIGHUP, SIGINT, SIGQUIT, SIGTERM)

# Register JACK callbacks
if jclient.setProcessCallback(processCb, osc.addr) != 0:
    error "Could not set JACK process callback function."
    cleanup()
    quit QuitFailure

jclient.onShutdown(shutdownCb, nil)

# Create output port
outPort = jclient.portRegister("out_1", JACK_DEFAULT_AUDIO_TYPE, PortIsOutput.ord, 0)

# Activate JACK client ...
if jclient.activate() == 0:
    # ... and keep running until a signal is received
    while not exitSignalled:
        sleep(50)

cleanup()
