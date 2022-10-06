# jacket.nim


# Possible names/install locations of libjack, according to
# https://github.com/x42/weakjack/blob/master/weak_libjack.c#L108
# 
# MacOS:
# * /usr/local/lib/libjack.dylib
# * /opt/homebrew/lib/libjack.dylib
# * /opt/local/lib/libjack.dylib
# Win:
# * libjack64.dll
# * libjack.dll
# Unix:
# * libjack.so.0
proc getJackLibName: string =
    when system.hostOS == "windows":
        result = "libjack.dll"
    elif system.hostOS == "macosx":
        result = "libjack.dylib"
    else:
        result = "libjack.so.0"
  
{.push dynlib: getJackLibName().}
const
    JACK_MAX_FRAMES* = (4294967295'i64)
    JACK_LOAD_INIT_LIMIT* = 1024
    JACK_DEFAULT_AUDIO_TYPE* = "32 bit float mono audio"
    JACK_DEFAULT_MIDI_TYPE* = "8 bit raw midi"

# ----------------------------- Custom Types ------------------------------

type
    TimeT* = culonglong
    NframesT* = culong
    UuidT* = culonglong
    PortIdT* = culong
    PortTypeIdT* = culong

type
    ClientT = object
    ClientTPtr* = ptr ClientT
    PortT = object
    PortTPtr* = ptr PortT


type
    JackOptions* {.size: sizeof(cint) pure.} = enum
        NullOption = 0x00,
        NoStartServer = 0x01,
        UseExactName = 0x02,
        ServerName = 0x04,
        LoadName = 0x08,
        LoadInit = 0x10,
        SessionID = 0x20

type
    JackStatus* {.size: sizeof(cint).} = enum
        Success = 0x00
        Failure = 0x01,
        InvalidOption = 0x02,
        NameNotUnique = 0x04,
        ServerStarted = 0x08,
        ServerFailed = 0x10,
        ServerError = 0x20,
        NoSuchClient = 0x40,
        LoadFailure = 0x80,
        InitFailure = 0x100,
        ShmFailure = 0x200,
        VersionError = 0x400,
        BackendError = 0x800,
        ClientZombie = 0x1000

type
    JackPortFlags* {.size: sizeof(culong) pure.} = enum
        PortIsInput = 0x1,
        PortIsOutput = 0x2,
        PortIsPhysical = 0x4,
        PortCanMonitor = 0x8,
        PortIsTerminal = 0x10

type
    JackLatencyCallbackMode* {.size: sizeof(cint) pure.} = enum
        CaptureLatency,
        PlaybackLatency

# Callback function types
type
    JackProcessCallback* = proc (nframes: NframesT; arg: pointer): cint
    JackThreadCallback* = proc (arg: pointer): pointer
    JackThreadInitCallback* = proc (arg: pointer)
    JackGraphOrderCallback* = proc (arg: pointer): cint
    JackXRunCallback* = proc (arg: pointer): cint
    JackBufferSizeCallback* = proc (nframes: NframesT; arg: pointer): cint
    JackSampleRateCallback* = proc (nframes: NframesT; arg: pointer): cint
    JackPortRegistrationCallback* = proc (port: PortIdT; flag: cint; arg: pointer)
    JackClientRegistrationCallback* = proc (name: cstring; flag: cint; arg: pointer)
    JackPortConnectCallback* = proc (portA: PortIdT; portB: PortIdT; connect: cint; arg: pointer)
    JackPortRenameCallback* = proc (port: PortIdT; oldName: cstring; newName: cstring; arg: pointer)
    JackFreewheelCallback* = proc (starting: cint; arg: pointer)
    JackShutdownCallback* = proc (arg: pointer)
    JackInfoShutdownCallback* = proc (code: JackStatus; reason: cstring; arg: pointer)
    JackLatencyCallback* = proc (mode: JackLatencyCallbackMode; arg: pointer)
    JackInfoCallback* = proc (msg: cstring)
    JackErrorCallback* = proc (msg: cstring)


# ----------------------------- Version info ------------------------------

# void jack_get_version(int *major_ptr, int *minor_ptr, int *micro_ptr, int *proto_ptr) ;
proc getVersion*(major: ptr cint; minor: ptr cint; micro: ptr cint; proto: ptr cint) {.importc: "jack_get_version".}

# const char * jack_get_version_string(void) ;
proc getVersionString*(): cstring {.importc: "jack_get_version_string".}


# --------------------------- Memory management ---------------------------

# void jack_free(void* ptr) ;
proc free*(`ptr`: pointer) {.importc: "jack_free".}


# -------------------------------- Clients --------------------------------

# jack_client_t * jack_client_open (char *client_name,
#                                   jack_options_t options,
#                                   jack_status_t *status, ...) ;
proc clientOpen*(clientName: cstring; options: cint; status: ptr cint): ClientTPtr {.
    varargs, importc: "jack_client_open".}

# DEPRECATED
# proc clientNew*(clientName: cstring): ClientTPtr {.importc: "jack_client_new".}

# int jack_client_close (jack_client_t *client) ;
proc clientClose*(client: ClientTPtr): cint {.importc: "jack_client_close"}

# int jack_client_name_size (void) ;
proc clientNameSize*(): cint {.importc: "jack_client_name_size"}

# char * jack_get_client_name (jack_client_t *client) ;
proc getClientName*(client: ClientTPtr): cstring {.importc: "jack_get_client_name".}

# char *jack_get_uuid_for_client_name (jack_client_t *client,
#                                      const char    *client_name) ;
proc getUuidForClientName*(client: ClientTPtr; clientName: cstring): cstring {.
    importc: "jack_get_uuid_for_client_name".}

# char *jack_get_client_name_by_uuid (jack_client_t *client,
#                                     const char    *client_uuid ) ;
proc getClientNameByUuid*(client: ClientTPtr; clientUuid: cstring): cstring {.
    importc: "jack_get_client_name_by_uuid".}

#[ FIXME: not implemented yet
proc internalClientNew*(clientName: cstring; loadName: cstring; loadInit: cstring): cint {.
    importc: "jack_internal_client_new".}

proc internalClientClose*(clientName: cstring) {.importc: "jack_internal_client_close".}
]#

# int jack_activate (jack_client_t *client) ;
proc activate*(client: ClientTPtr): cint {.importc: "jack_activate".}

# int jack_deactivate (jack_client_t *client) ;
proc deactivate*(client: ClientTPtr): cint {.importc: "jack_deactivate".}

# int jack_get_client_pid (const char *name) ;
proc getClientPid*(name: cstring): cint {.importc: "jack_get_client_pid".}

# FIXME: not implemented yet
# jack_native_thread_t jack_client_thread_id (jack_client_t *client) ;
# proc clientThreadId*(client: ClientTPtr): NativeThreadT {.
#    importc: "jack_client_thread_id".}

# int jack_is_realtime (jack_client_t *client) ;
proc isRealtime*(client: ClientTPtr): cint {.importc: "jack_is_realtime".}

# DEPRECATED
# proc threadWait*(client: ClientTPtr; status: cint): NframesT {.
#     importc: "jack_thread_wait".}

# jack_nframes_t jack_cycle_wait (jack_client_t* client) ;
proc cycleWait*(client: ClientTPtr): NframesT {.importc: "jack_cycle_wait".}

# void jack_cycle_signal (jack_client_t* client, int status) ;
proc cycleSignal*(client: ClientTPtr; status: cint) {.importc: "jack_cycle_signal".}


# ------------------------------- Callbacks -------------------------------

proc setProcessThread*(client: ClientTPtr; threadCallback: JackThreadCallback; arg: pointer): cint {.
    importc: "jack_set_process_thread".}

proc setThreadInitCallback*(client: ClientTPtr; threadInitCallback: JackThreadInitCallback; arg: pointer): cint {.
    importc: "jack_set_thread_init_callback".}

proc onShutdown*(client: ClientTPtr; shutdownCallback: JackShutdownCallback; arg: pointer) {.
    importc: "jack_on_shutdown".}

proc onInfoShutdown*(client: ClientTPtr; shutdownCallback: JackInfoShutdownCallback; arg: pointer) {.
    importc: "jack_on_info_shutdown".}

proc setProcessCallback*(client: ClientTPtr; processCallback: JackProcessCallback; arg: pointer): cint {.
    importc: "jack_set_process_callback".}

proc setFreewheelCallback*(client: ClientTPtr; freewheelCallback: JackFreewheelCallback; arg: pointer): cint {.
    importc: "jack_set_freewheel_callback".}

proc setBufferSizeCallback*(client: ClientTPtr; bufsizeCallback: JackBufferSizeCallback; arg: pointer): cint {.
    importc: "jack_set_buffer_size_callback".}

proc setSampleRateCallback*(client: ClientTPtr; srateCallback: JackSampleRateCallback; arg: pointer): cint {.
    importc: "jack_set_sample_rate_callback".}

proc setClientRegistrationCallback*(client: ClientTPtr; registrationCallback: JackClientRegistrationCallback;
                                    arg: pointer): cint {.
    importc: "jack_set_client_registration_callback".}

proc setPortRegistrationCallback*(client: ClientTPtr; registrationCallback: JackPortRegistrationCallback;
                                  arg: pointer): cint {.
    importc: "jack_set_port_registration_callback".}

proc setPortConnectCallback*(client: ClientTPtr; connectCallback: JackPortConnectCallback; arg: pointer): cint {.
    importc: "jack_set_port_connect_callback".}

proc setPortRenameCallback*(client: ClientTPtr; renameCallback: JackPortRenameCallback; arg: pointer): cint {.
    importc: "jack_set_port_rename_callback".}

proc setGraphOrderCallback*(client: ClientTPtr; graphCallback: JackGraphOrderCallback; a3: pointer): cint {.
    importc: "jack_set_graph_order_callback".}

proc setXrunCallback*(client: ClientTPtr; xrunCallback: JackXRunCallback; arg: pointer): cint {.
    importc: "jack_set_xrun_callback".}

proc setLatencyCallback*(client: ClientTPtr; latencyCallback: JackLatencyCallback; arg: pointer): cint {.
    importc: "jack_set_latency_callback".}


# -------------------------- Server Client Control ------------------------

# int jack_set_freewheel(jack_client_t* client, int onoff) ;
proc setFreewheel*(client: ClientTPtr; onoff: cint): cint {.importc: "jack_set_freewheel".}

# int jack_set_buffer_size (jack_client_t *client, jack_nframes_t nframes) ;
proc setBufferSize*(client: ClientTPtr; nframes: NframesT): cint {.importc: "jack_set_buffer_size".}

#jack_nframes_t jack_get_sample_rate (jack_client_t *) ;
proc getSampleRate*(client: ClientTPtr): NframesT {.importc: "jack_get_sample_rate".}

# jack_nframes_t jack_get_buffer_size (jack_client_t *) ;
proc getBufferSize*(client: ClientTPtr): NframesT {.importc: "jack_get_buffer_size".}

# DEPRECATED
# proc engineTakeoverTimebase*(a1: ClientTPtr): cint {.
#    importc: "jack_engine_takeover_timebase".}

# float jack_cpu_load (jack_client_t *client) ;
proc cpuLoad*(client: ClientTPtr): cfloat {.importc: "jack_cpu_load".}


# --------------------------------- Ports ---------------------------------

# jack_port_t * jack_port_register (jack_client_t *client,
#                                   const char *port_name,
#                                   const char *port_type,
#                                   unsigned long flags,
#                                   unsigned long buffer_size) ;
proc portRegister*(client: ClientTPtr; portName: cstring; portType: cstring;
                   flags: culong; bufferSize: culong): PortTPtr {.importc: "jack_port_register".}

# int jack_port_unregister (jack_client_t *client, jack_port_t *port) ;
proc portUnregister*(client: ClientTPtr; port: PortTPtr): cint {.importc: "jack_port_unregister".}

# void * jack_port_get_buffer (jack_port_t *port, jack_nframes_t) ;
proc portGetBuffer*(port: PortTPtr; nframes: NframesT): pointer {.importc: "jack_port_get_buffer".}

# jack_uuid_t jack_port_uuid (const jack_port_t *port) ;
proc portUuid*(port: PortTPtr): UuidT {.importc: "jack_port_uuid".}

# const char * jack_port_name (const jack_port_t *port) ;
proc portName*(port: PortTPtr): cstring {.importc: "jack_port_name".}

# const char * jack_port_short_name (const jack_port_t *port) ;
proc portShortName*(port: PortTPtr): cstring {.importc: "jack_port_short_name".}

# int jack_port_flags (const jack_port_t *port) ;
proc portFlags*(port: PortTPtr): cint {.importc: "jack_port_flags".}

# const char * jack_port_type (const jack_port_t *port) ;
proc portType*(port: PortTPtr): cstring {.importc: "jack_port_type".}

# jack_port_type_id_t jack_port_type_id (const jack_port_t *port) ;
proc portTypeId*(port: PortTPtr): PortTypeIdT {.importc: "jack_port_type_id".}

# int jack_port_is_mine (const jack_client_t *client, const jack_port_t *port) ;
proc portIsMine*(client: ClientTPtr; port: PortTPtr): cint {.
    importc: "jack_port_is_mine".}

# int jack_port_connected (const jack_port_t *port) ;
proc portConnected*(port: PortTPtr): cint {.importc: "jack_port_connected".}

# int jack_port_connected_to (const jack_port_t *port,
#                             const char *port_name) ;
proc portConnectedTo*(port: PortTPtr; portName: cstring): cint {.importc: "jack_port_connected_to".}

# const char ** jack_port_get_connections (const jack_port_t *port) ;
#
# CAVEAT: The caller is responsible for calling jack_free() on any non-NULL
# returned value.
proc portGetConnections*(port: PortTPtr): cstringArray {.importc: "jack_port_get_connections".}

# const char ** jack_port_get_all_connections (const jack_client_t *client,
#                                              const jack_port_t *port) ;
#
# CAVEAT: The caller is responsible for calling jack_free() on any non-NULL
# returned value.
proc portGetAllConnections*(client: ClientTPtr; port: PortTPtr): cstringArray {.
    importc: "jack_port_get_all_connections".}

#[ DEPRECATED
proc portTie*(src: PortTPtr; dst: PortTPtr): cint {.importc: "jack_port_tie".}

proc portUntie*(port: PortTPtr): cint {.importc: "jack_port_untie".}

proc portSetName*(port: PortTPtr; portName: cstring): cint {.importc: "jack_port_set_name".}
]#

# int jack_port_rename (jack_client_t* client, jack_port_t *port, const char *port_name) ;
proc portRename*(client: ClientTPtr; port: PortTPtr; portName: cstring): cint {.importc: "jack_port_rename".}

# int jack_port_set_alias (jack_port_t *port, const char *alias) ;
proc portSetAlias*(port: PortTPtr; alias: cstring): cint {.importc: "jack_port_set_alias".}

# int jack_port_unset_alias (jack_port_t *port, const char *alias) ;
proc portUnsetAlias*(port: PortTPtr; alias: cstring): cint {.importc: "jack_port_unset_alias".}

# int jack_port_get_aliases (const jack_port_t *port, char* const aliases[2]) ;
proc portGetAliases*(port: PortTPtr; aliases: array[2, cstring]): cint {.importc: "jack_port_get_aliases".}

#int jack_port_request_monitor (jack_port_t *port, int onoff) ;
proc portRequestMonitor*(port: PortTPtr; onoff: cint): cint {.importc: "jack_port_request_monitor".}

# int jack_port_request_monitor_by_name (jack_client_t *client,
#                                        const char *port_name, int onoff) ;
proc portRequestMonitorByName*(client: ClientTPtr; portName: cstring; onoff: cint): cint {.
    importc: "jack_port_request_monitor_by_name".}

# int jack_port_ensure_monitor (jack_port_t *port, int onoff) ;
proc portEnsureMonitor*(port: PortTPtr; onoff: cint): cint {.
    importc: "jack_port_ensure_monitor".}

# int jack_port_monitoring_input (jack_port_t *port) ;
proc portMonitoringInput*(port: PortTPtr): cint {.importc: "jack_port_monitoring_input".}

# ------------------------------ Connections ------------------------------

# int jack_connect (jack_client_t *client,
#                   const char *source_port,
#                   const char *destination_port) ;
proc connect*(client: ClientTPtr; srcPort: cstring; destPort: cstring): cint {.importc: "jack_connect".}

# int jack_disconnect (jack_client_t *client,
#                      const char *source_port,
#                      const char *destination_port) ;
proc disconnect*(client: ClientTPtr; srcPort: cstring; destPort: cstring): cint {.importc: "jack_disconnect".}

# int jack_port_disconnect (jack_client_t *client, jack_port_t *port) ;
proc portDisconnect*(client: ClientTPtr; port: PortTPtr): cint {.importc: "jack_port_disconnect".}

# int jack_port_name_size(void) ;
proc portNameSize*(): cint {.importc: "jack_port_name_size".}

# int jack_port_type_size(void) ;
proc portTypeSize*(): cint {.importc: "jack_port_type_size".}

# size_t jack_port_type_get_buffer_size (jack_client_t *client, const char *port_type) ;
proc portTypeGetBufferSize*(client: ClientTPtr; portType: cstring): csize_t {.
    importc: "jack_port_type_get_buffer_size".}

# -------------------------------- Latency --------------------------------

#[ FIXME: not implemented yet
# void jack_port_set_latency (jack_port_t *port, jack_nframes_t) ;
proc portSetLatency*(port: PortTPtr; a2: NframesT) {.importc: "jack_port_set_latency".}

#[ FIXME: not implemented yet
# void jack_port_get_latency_range (jack_port_t *port, jack_latency_callback_mode_t mode, jack_latency_range_t *range) ;
proc portGetLatencyRange*(port: PortTPtr; mode: LatencyCallbackModeT;
                         range: ptr LatencyRangeT) {.importc: "jack_port_get_latency_range".}

proc portSetLatencyRange*(port: PortTPtr; mode: LatencyCallbackModeT;
                         range: ptr LatencyRangeT) {.importc: "jack_port_set_latency_range".}
]#

proc recomputeTotalLatencies*(client: ClientTPtr): cint {.importc: "jack_recompute_total_latencies".}

proc portGetLatency*(port: PortTPtr): NframesT {.importc: "jack_port_get_latency".}

proc portGetTotalLatency*(client: ClientTPtr; port: PortTPtr): NframesT {.importc: "jack_port_get_total_latency".}

proc recomputeTotalLatency*(a1: ClientTPtr; port: PortTPtr): cint {.importc: "jack_recompute_total_latency".}
]#

# ------------------------------ Port Lookup ------------------------------

# const char ** jack_get_ports (jack_client_t *client,
#                               const char *port_name_pattern,
#                               const char *type_name_pattern,
#                               unsigned long flags) ;
#
# CAVEAT: The caller is responsible for calling jack_free() on any non-NULL
# returned value.
proc getPorts*(client: ClientTPtr; portNamePattern: cstring;
               typeNamePattern: cstring; flags: culong): cstringArray {.importc: "jack_get_ports".}

# jack_port_t * jack_port_by_name (jack_client_t *client, const char *port_name) ;
proc portByName*(client: ClientTPtr; portName: cstring): PortTPtr {.importc: "jack_port_by_name".}

# jack_port_t * jack_port_by_id (jack_client_t *client, jack_port_id_t port_id) ;
proc portById*(client: ClientTPtr; portId: PortIdT): PortTPtr {.importc: "jack_port_by_id".}

# ----------------------------- Time handling -----------------------------

# jack_nframes_t jack_frames_since_cycle_start (const jack_client_t *) ;
proc framesSinceCycleStart*(client: ClientTPtr): NframesT {.importc: "jack_frames_since_cycle_start".}

# jack_nframes_t jack_frame_time (const jack_client_t *) ;
proc frameTime*(client: ClientTPtr): NframesT {.importc: "jack_frame_time".}

# jack_nframes_t jack_last_frame_time (const jack_client_t *client) ;
proc lastFrameTime*(client: ClientTPtr): NframesT {.importc: "jack_last_frame_time".}

# int jack_get_cycle_times(const jack_client_t *client,
#                         jack_nframes_t *current_frames,
#                         jack_time_t    *current_usecs,
#                         jack_time_t    *next_usecs,
#                         float          *period_usecs) ;
proc getCycleTimes*(client: ClientTPtr; currentFrames: ptr NframesT;
                    currentUsecs: ptr TimeT; nextUsecs: ptr TimeT;
                    periodUsecs: ptr cfloat): cint {.importc: "jack_get_cycle_times".}

# jack_time_t jack_frames_to_time(const jack_client_t *client, jack_nframes_t) ;
proc framesToTime*(client: ClientTPtr; nframes: NframesT): TimeT {.importc: "jack_frames_to_time".}

# jack_nframes_t jack_time_to_frames(const jack_client_t *client, jack_time_t) ;
proc timeToFrames*(client: ClientTPtr; time: TimeT): NframesT {.importc: "jack_time_to_frames".}

# jack_time_t jack_get_time(void) ;
proc getTime*(): TimeT {.importc: "jack_get_time".}

# ---------------------------- Error handling -----------------------------

proc setErrorFunction*(errorCallback: JackErrorCallback) {.importc: "jack_set_error_function".}

proc setInfoFunction*(infoCallback: JackInfoCallback) {.importc: "jack_set_info_function".}

{.pop.}

proc getJackStatusErrorString*(status: cint): string =
    # Get JACK error status as string.
    if status == ord(Success):
        return ""

    var errorString = ""

    if status == ord(Failure):
        # Only include this generic message if no other error status is set
        errorString = "Overall operation failed"
    if (status and ord(InvalidOption)) > 0:
        errorString &= "\nThe operation contained an invalid and unsupported option"
    if (status and ord(NameNotUnique)) > 0:
        errorString &= "\nThe desired client name was not unique"
    if (status and ord(ServerStarted)) > 0:
        errorString &= "\nThe JACK server was started as a result of this operation"
    if (status and ord(ServerFailed)) > 0:
        errorString &= "\nUnable to connect to the JACK server"
    if (status and ord(ServerError)) > 0:
        errorString &= "\nCommunication error with the JACK server"
    if (status and ord(NoSuchClient)) > 0:
        errorString &= "\nRequested client does not exist"
    if (status and ord(LoadFailure)) > 0:
        errorString &= "\nUnable to load internal client"
    if (status and ord(InitFailure)) > 0:
        errorString &= "\nUnable to initialize client"
    if (status and ord(ShmFailure)) > 0:
        errorString &= "\nUnable to access shared memory"
    if (status and ord(VersionError)) > 0:
        errorString &= "\nClient's protocol version does not match"
    if (status and ord(BackendError)) > 0:
        errorString &= "\nBackend Error"
    if (status and ord(ClientZombie)) > 0:
        errorString &= "\nClient is being shutdown against its will"

    return errorString
