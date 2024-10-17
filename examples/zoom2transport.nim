##
## Control JACK transport with foot switch connected to Zoom R8 audio interface
##
## Requires: https://github.com/SpotlightKid/jacket

import std/[cmdline, logging, os, re, strformat]
import threading/channels
import signal
import jacket


const MidiNoteOn: byte = 0x90
const McpRewind: byte = 91
const McpForward: byte = 92
const McpStop: byte = 93
const McpPlay: byte = 94
const McpPunchInOut: byte = 95

type
  ConnectionInfo = tuple[name: string, pattern: string]

  App = object
    client: ClientP
    logger: ConsoleLogger
    midiIn: PortP

var
  jclient: ClientP
  event: MidiEvent
  midiPort: PortP
  status: cint
  srcPortPtn: string
  portChan: Chan[ConnectionInfo]
  portConnecter: Thread[App]
  exitSignalled: bool = false

var log = newConsoleLogger(when defined(release): lvlInfo else: lvlDebug)


proc cleanup() =
  debug "Cleaning up..."
  if jclient != nil:
    discard jclient.deactivate()

    if portConnecter.running:
        debug "Stopping port connecter thread..."
        discard portChan.trySend((name: "", pattern: ""))

    portConnecter.joinThread()

    discard jclient.clientClose()
    jclient = nil

proc errorCb(msg: cstring) {.cdecl.} =
  # Suppress verbose JACK error messages when server is not available by
  # default. Pass ``lvlAll`` when creating the logger to enable them.
  debug "JACK error: " & $msg

proc signalCb(sig: cint) {.noconv.} =
  debug "Received signal: " & $sig
  exitSignalled = true

proc shutdownCb(arg: pointer = nil) {.cdecl.} =
  warn "JACK server has shut down."
  exitSignalled = true

proc isStatus(event: MidiEvent, status: byte): bool =
  return (event.buffer[0] and 0xF0) == status

proc processCb*(nFrames: NFrames, arg: pointer): cint {.cdecl.} =
  let app = cast[ptr App](arg)
  let inbuf = portGetBuffer(app.midiIn, nFrames)
  let count = midiGetEventCount(inbuf)

  for i in 0..<count:
    if midiEventGet(event.addr, inbuf, i.uint32) == 0:
      if isStatus(event, MidiNoteOn):
        var pos: Position
        let transportState = transportQuery(jclient, pos.addr)

        case event.buffer[1].byte
        of McpRewind:
          app.logger.log(lvlDebug, "Setting transport position to frame = 0")
          discard transportLocate(app.client, 0)
        of McpForward:
          let new_pos = pos.frame + pos.frame_rate
          app.logger.log(lvlDebug, "Setting transport position to frame = " & $new_pos)
          discard transportLocate(app.client, new_pos)
        of McpStop:
          if (transportState == TransportRolling or
              transportState == TransportStarting or
              transportState == TransportNetStarting):
            app.logger.log(lvlDebug, "STOPPING JACK transport")
            transportStop(app.client)
        of McpPlay:
          if transportState == TransportStopped:
            app.logger.log(lvlDebug, "STARTING JACK transport")
            transportStart(app.client)
        of McpPunchInOut:
          if transportState == TransportStopped:
            app.logger.log(lvlDebug, "STARTING JACK transport")
            transportStart(app.client)
          else:
            app.logger.log(lvlDebug, "STOPPING JACK transport")
            transportStop(app.client)
        else:
          discard

proc findPort(client: ClientP, pattern: string): string =
  let ports = getPorts(client, pattern, JACK_DEFAULT_MIDI_TYPE, PortIsOutput)

  if not ports.isNil():
    result = $ports[0]
    free(ports)

proc portRegisterCb(port: PortId; flag: cint; arg: pointer) {.cdecl.} =
  if flag == 0:
    return

  let portP = jclient.portById(port)

  if not portP.isNil():
    let info: ConnectionInfo = (name: $portName(portP), pattern: srcPortPtn)

    if not portChan.trySend(info):
      writeLine stderr, "Port connecter channel overflow!"

proc portConnecterProc(app: App) {.thread.} =
    var info: ConnectionInfo
    addHandler(app.logger)
    setLogFilter(when defined(release): lvlInfo else: lvlDebug)

    while true:
      portChan.recv(info)

      if info.name == "":
        break

      debug &"New port: {info.name}"

      if contains(info.name, re(info.pattern)):
        if portConnectedTo(midiPort, info.name.cstring) != 1:
          if app.client.connect(info.name.cstring, portName(app.midiIn)) != 1:
            debug &"Connected input to port {info.name}"
          else:
            warn &"Failed to connect to port {info.name}"

proc main() =
  addHandler(log)

  # Create JACK client
  setErrorFunction(errorCb)
  jclient = clientOpen("zoom2transport", NoStartServer or UseExactName, status.addr)
  debug "JACK server status: " & $status

  if jclient == nil:
    error getJackStatusErrorString(status)
    quit QuitFailure

  # Set up signal handlers to clean up on exit
  when defined(windows):
    setSignalProc(signalCb, SIGABRT, SIGINT, SIGTERM)
  else:
    setSignalProc(signalCb, SIGABRT, SIGHUP, SIGINT, SIGQUIT, SIGTERM)

  # Create output port
  midiPort = jclient.portRegister("midi_in", JACK_DEFAULT_MIDI_TYPE, PortIsInput, 0)
  var app = App(client: jclient, logger: log, midiIn: midiPort)

  portChan = newChan[ConnectionInfo]()
  createThread(portConnecter, portConnecterProc, app)

  # Register JACK callbacks
  if jclient.setProcessCallback(processCb, app.addr) != 0:
    error "Could not set JACK process callback function."
    cleanup()
    quit QuitFailure

  jclient.onShutdown(shutdownCb)

  if paramCount() > 0:
    srcPortPtn = paramStr(1)

    if jclient.setPortRegistrationCallback(portRegisterCb) != 0:
      error "Error: could not set JACK port registration callback."
      cleanup()
      quit QuitFailure
  else:
    srcPortPtn = ""

  # Activate JACK client ...
  if jclient.activate() == 0:
    # try to connect input to port given via port pattern on command line
    if srcPortPtn != "":
      let srcPortName = findPort(jclient, srcPortPtn)

      if srcPortName != "" and portConnectedTo(midiPort, srcPortName.cstring) != 1:
        if jclient.connect(srcPortName.cstring, portName(midiPort)) != 1:
          debug &"Connected input to port {srcPortName}"
        else:
          warn &"Failed to connect to port {srcPortName}"

    # ... and keep running until a signal is received
    while not exitSignalled:
      sleep(100)

  cleanup()


when isMainModule:
    main()
