# jacket.nim


# Possible names/install locations of libjack, according to:
# https://github.com/x42/weakjack/blob/master/weak_libjack.c#L108
proc getJackLibName: string =
    when system.hostOS == "windows":
        when sizeof(int) == 4:
            result = "libjack.dll"
        else:
            result = "libjack64.dll"
    elif system.hostOS == "macosx":
        result = "(|/usr/local/lib/|/opt/homebrew/lib/|/opt/local/lib/)libjack.dylib"
    else:
        result = "libjack.so.0"

{.push dynlib: getJackLibName().}

# ------------------------------ Constants --------------------------------

const
    JACK_MAX_FRAMES* = (4294967295'i64)
    JACK_LOAD_INIT_LIMIT* = 1024
    JACK_DEFAULT_AUDIO_TYPE* = "32 bit float mono audio"
    JACK_DEFAULT_MIDI_TYPE* = "8 bit raw midi"


# ----------------------------- Custom Types ------------------------------

type
    Time* = uint64
    NFrames* = uint32
    IntClient = uint64
    Uuid* = uint64
    PortId* = uint32
    PortTypeId* = uint32
    DefaultAudioSample* = cfloat

type
    Client = distinct object
    ClientP* = ptr Client
    Port = distinct object
    PortP* = ptr Port

type
    MidiData* = uint8
    MidiEvent* = object
        time*: NFrames
        size*: csize_t
        buffer*: ptr UncheckedArray[MidiData]
    MidiEventP* = ptr MidiEvent

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
    JackStatus* {.size: sizeof(cint) pure.} = enum
        Success = 0x00,
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
    PortFlags* {.size: sizeof(culong) pure.} = enum
        PortIsInput = 0x01,
        PortIsOutput = 0x02,
        PortIsPhysical = 0x04,
        PortCanMonitor = 0x08,
        PortIsTerminal = 0x10

type
    LatencyRange* = object
        min*: NFrames
        max*: NFrames

    LatencyCallbackMode* {.size: sizeof(cint) pure.} = enum
        CaptureLatency,
        PlaybackLatency

# Transport

type
    PositionBits* {.size: sizeof(cint) pure.} = enum
        PositionBBT = 0x10,
        PositionTimecode = 0x20,
        BBTFrameOffset = 0x40,
        AudioVideoRatio = 0x80,
        VideoFrameOffset = 0x100,
        TickDouble = 0x200

    TransportState* {.size: sizeof(cint) pure.} = enum
        TransportStopped = 0,
        TransportRolling = 1,
        TransportLooping = 2,
        TransportStarting = 3,
        TransportNetStarting = 4

type
    Position* = object
        unique1*: uint64
        usecs*: Time
        frameRate*: NFrames
        frame*: NFrames
        valid*: PositionBits
        bar*: int32
        beat*: int32
        tick*: int32
        barStartTick*: cdouble
        beatsPerBar*: cfloat
        beatType*: cfloat
        ticksPerBeat*: cdouble
        beatsPerMinute*: cdouble
        frameTime*: cdouble
        nextTime*: cdouble
        bbtOffset*: NFrames
        audioFramesPerVideoFrame*: cfloat
        videoOffset*: NFrames
        tickDouble*: cdouble
        padding*: array[5, int32]
        unique2*: uint64
    PositionP* = ptr Position

#[ DEPRECATED
typedef enum {
    JackTransportState = 0x1,
    JackTransportPosition = 0x2,
    JackTransportLoop = 0x4,
    JackTransportSMPTE = 0x8,
    JackTransportBBT = 0x10
} jack_transport_bits_t;

typedef struct {
    jack_nframes_t frame_rate;
    jack_time_t usecs;
    jack_transport_bits_t valid;
    jack_transport_state_t transport_state;
    jack_nframes_t frame;
    jack_nframes_t loop_start;
    jack_nframes_t loop_end;
    long smpte_offset
    float smpte_frame_rate;
    int bar;
    int beat;
    int tick;
    double bar_start_tick;
    float beats_per_bar;
    float beat_type;
    double ticks_per_beat;
    double beats_per_minute;
} jack_transport_info_t;
]#

const
    JACK_POSITION_MASK* = (PositionBBT.ord or PositionTimecode.ord)
    EXTENDED_TIME_INFO* = true
    JACK_TICK_DOUBLE* = true

# Ringbuffer

type
    RingbufferData* = object
        buf*: ptr char
        len*: csize_t
    RingbufferDataP* = ptr RingbufferData

    Ringbuffer = distinct object
    RingbufferP* = ptr Ringbuffer

# Metadata

type
    Property* = object
        key*: cstring
        data*: cstring
        `type`*: cstring

    PropertyChange* {.size: sizeof(cint) pure.} = enum
        PropertyCreated,
        PropertyChanged,
        PropertyDeleted

    Description* = object
        subject*: Uuid
        property_cnt*: uint32
        properties*: ptr UncheckedArray[Property]
        property_size*: uint32

    DescriptionP* = ptr Description

# Callback function types

type
    ProcessCallback* = proc (nframes: NFrames; arg: pointer): cint {.cdecl.}
    ThreadCallback* = proc (arg: pointer): pointer {.cdecl.}
    ThreadInitCallback* = proc (arg: pointer) {.cdecl.}
    GraphOrderCallback* = proc (arg: pointer): cint {.cdecl.}
    XRunCallback* = proc (arg: pointer): cint {.cdecl.}
    BufferSizeCallback* = proc (nframes: NFrames; arg: pointer): cint {.cdecl.}
    SampleRateCallback* = proc (nframes: NFrames; arg: pointer): cint {.cdecl.}
    PortRegistrationCallback* = proc (port: PortId; flag: cint; arg: pointer) {.cdecl.}
    ClientRegistrationCallback* = proc (name: cstring; flag: cint; arg: pointer) {.cdecl.}
    PortConnectCallback* = proc (portA: PortId; portB: PortId; connect: cint; arg: pointer) {.cdecl.}
    PortRenameCallback* = proc (port: PortId; oldName: cstring; newName: cstring; arg: pointer) {.cdecl.}
    FreewheelCallback* = proc (starting: cint; arg: pointer) {.cdecl.}
    ShutdownCallback* = proc (arg: pointer) {.cdecl.}
    InfoShutdownCallback* = proc (code: JackStatus; reason: cstring; arg: pointer) {.cdecl.}
    LatencyCallback* = proc (mode: LatencyCallbackMode; arg: pointer) {.cdecl.}
    InfoCallback* = proc (msg: cstring) {.cdecl.}
    ErrorCallback* = proc (msg: cstring) {.cdecl.}

    SyncCallback* = proc (state: TransportState; pos: ptr Position; arg: pointer): cint {.cdecl.}
    TimebaseCallback* = proc (state: TransportState; nframes: NFrames; pos: ptr Position; newPos: cint;
                              arg: pointer) {.cdecl.}

    PropertyChangeCallback* = proc (subject: Uuid, key: cstring, change: PropertyChange, arg: pointer) {.cdecl.}


# ------------------------- Converters for Enums --------------------------

converter jackIntEnumToCInt*[T: JackOptions | JackStatus | LatencyCallbackMode |
    PositionBits | TransportState | PropertyChange](x: T): cint = x.ord.cint
converter portFlagsToCULong*(x: PortFlags): culong = x.ord.culong

# ----------------------------- Version info ------------------------------

# void jack_get_version(int *major_ptr, int *minor_ptr, int *micro_ptr, int *proto_ptr)
proc getVersion*(major: ptr cint; minor: ptr cint; micro: ptr cint; proto: ptr cint) {.importc: "jack_get_version".}

# const char * jack_get_version_string(void)
proc getVersionString*(): cstring {.importc: "jack_get_version_string".}


# --------------------------- Memory management ---------------------------

# void jack_free(void* ptr)
proc free*(`ptr`: pointer) {.importc: "jack_free".}


# -------------------------------- Clients --------------------------------

# jack_client_t * jack_client_open (char *client_name,
#                                   jack_options_t options,
#                                   jack_status_t *status, ...)
proc clientOpen*(clientName: cstring; options: cint; status: ptr cint): ClientP {.
    varargs, importc: "jack_client_open".}

# int jack_client_close (jack_client_t *client)
proc clientClose*(client: ClientP): cint {.importc: "jack_client_close"}

# int jack_client_name_size (void)
proc clientNameSize*(): cint {.importc: "jack_client_name_size"}

# char * jack_get_client_name (jack_client_t *client)
proc getClientName*(client: ClientP): cstring {.importc: "jack_get_client_name".}

# char *jack_get_uuid_for_client_name (jack_client_t *client, const char *client_name)
proc getUuidForClientName*(client: ClientP; clientName: cstring): cstring {.
    importc: "jack_get_uuid_for_client_name".}

# char *jack_get_client_name_by_uuid (jack_client_t *client, const char *client_uuid)
proc getClientNameByUuid*(client: ClientP; clientUuid: cstring): cstring {.
    importc: "jack_get_client_name_by_uuid".}

# int jack_activate (jack_client_t *client)
proc activate*(client: ClientP): cint {.importc: "jack_activate".}

# int jack_deactivate (jack_client_t *client)
proc deactivate*(client: ClientP): cint {.importc: "jack_deactivate".}

# int jack_get_client_pid (const char *name)
proc getClientPid*(name: cstring): cint {.importc: "jack_get_client_pid".}

# FIXME: not implemented yet
# jack_native_thread_t jack_client_thread_id (jack_client_t *client)
# proc clientThreadId*(client: ClientP): NativeThread {.importc: "jack_client_thread_id".}

# int jack_is_realtime (jack_client_t *client)
proc isRealtime*(client: ClientP): cint {.importc: "jack_is_realtime".}

# jack_nframes_t jack_cycle_wait (jack_client_t* client)
proc cycleWait*(client: ClientP): NFrames {.importc: "jack_cycle_wait".}

# void jack_cycle_signal (jack_client_t* client, int status)
proc cycleSignal*(client: ClientP; status: cint) {.importc: "jack_cycle_signal".}

#[ DEPRECATED
jack_client_t *jack_client_new (const char *client_name)
jack_nframes_t jack_thread_wait (jack_client_t *client, int status)
]#

# --------------------------- Internal Clients ----------------------------

# char *jack_get_internal_client_name (jack_client_t *client, jack_intclient_t intclient);
proc getInternalClientName*(client: ClientP; intclient: IntClient): cstring {.
    importc: "jack_get_internal_client_name".}

# jack_intclient_t jack_internal_client_handle (jack_client_t *client, const char *client_name,
#                                               jack_status_t *status)
proc internalClientHandle*(client: ClientP; clientName: cstring; status: ptr cint): IntClient {.
    importc: "jack_internal_client_handle".}

# jack_intclient_t jack_internal_client_load (jack_client_t *client, const char *client_name,
#                                             jack_options_t options, jack_status_t *status, ...)
proc internalClientLoad*(client: ClientP; clientName: cstring; options: cint; status: ptr cint): IntClient {.
    varargs, importc: "jack_internal_client_load".}

# jack_status_t jack_internal_client_unload (jack_client_t *client, jack_intclient_t intclient)

proc internalClientUnload*(client: ClientP; intclient: IntClient): cint {.
    importc: "jack_internal_client_unload".}

#[ DEPRECATED
int jack_internal_client_new (const char * client_name, const char *load_name, const char *load_init)
void jack_internal_client_close (const char *client_name)
]#


# ------------------------------- Callbacks -------------------------------

proc setProcessThread*(client: ClientP; threadCallback: ThreadCallback; arg: pointer = nil): cint {.
    importc: "jack_set_process_thread".}

proc setThreadInitCallback*(client: ClientP; threadInitCallback: ThreadInitCallback; arg: pointer = nil): cint {.
    importc: "jack_set_thread_init_callback".}

proc onShutdown*(client: ClientP; shutdownCallback: ShutdownCallback; arg: pointer = nil) {.
    importc: "jack_on_shutdown".}

proc onInfoShutdown*(client: ClientP; shutdownCallback: InfoShutdownCallback; arg: pointer = nil) {.
    importc: "jack_on_info_shutdown".}

proc setProcessCallback*(client: ClientP; processCallback: ProcessCallback; arg: pointer = nil): cint {.
    importc: "jack_set_process_callback".}

proc setFreewheelCallback*(client: ClientP; freewheelCallback: FreewheelCallback; arg: pointer = nil): cint {.
    importc: "jack_set_freewheel_callback".}

proc setBufferSizeCallback*(client: ClientP; bufsizeCallback: BufferSizeCallback; arg: pointer = nil): cint {.
    importc: "jack_set_buffer_size_callback".}

proc setSampleRateCallback*(client: ClientP; srateCallback: SampleRateCallback; arg: pointer = nil): cint {.
    importc: "jack_set_sample_rate_callback".}

proc setClientRegistrationCallback*(client: ClientP; registrationCallback: ClientRegistrationCallback;
                                    arg: pointer = nil): cint {.
    importc: "jack_set_client_registration_callback".}

proc setPortRegistrationCallback*(client: ClientP; registrationCallback: PortRegistrationCallback;
                                  arg: pointer = nil): cint {.
    importc: "jack_set_port_registration_callback".}

proc setPortConnectCallback*(client: ClientP; connectCallback: PortConnectCallback; arg: pointer = nil): cint {.
    importc: "jack_set_port_connect_callback".}

proc setPortRenameCallback*(client: ClientP; renameCallback: PortRenameCallback; arg: pointer = nil): cint {.
    importc: "jack_set_port_rename_callback".}

proc setGraphOrderCallback*(client: ClientP; graphCallback: GraphOrderCallback; a3: pointer): cint {.
    importc: "jack_set_graph_order_callback".}

proc setXrunCallback*(client: ClientP; xrunCallback: XRunCallback; arg: pointer = nil): cint {.
    importc: "jack_set_xrun_callback".}

proc setLatencyCallback*(client: ClientP; latencyCallback: LatencyCallback; arg: pointer = nil): cint {.
    importc: "jack_set_latency_callback".}


# -------------------------- Server Client Control ------------------------

# int jack_set_freewheel(jack_client_t* client, int onoff)
proc setFreewheel*(client: ClientP; onoff: cint): cint {.importc: "jack_set_freewheel".}

# int jack_set_buffer_size (jack_client_t *client, jack_nframes_t nframes)
proc setBufferSize*(client: ClientP; nframes: NFrames): cint {.importc: "jack_set_buffer_size".}

#jack_nframes_t jack_get_sample_rate (jack_client_t *)
proc getSampleRate*(client: ClientP): NFrames {.importc: "jack_get_sample_rate".}

# jack_nframes_t jack_get_buffer_size (jack_client_t *)
proc getBufferSize*(client: ClientP): NFrames {.importc: "jack_get_buffer_size".}

# float jack_cpu_load (jack_client_t *client)
proc cpuLoad*(client: ClientP): cfloat {.importc: "jack_cpu_load".}

#[ DEPRECATED
int jack_engine_takeover_timebase (jack_client_t *)
]#


# --------------------------------- Ports ---------------------------------

# jack_port_t * jack_port_register (jack_client_t *client,
#                                   const char *port_name,
#                                   const char *port_type,
#                                   unsigned long flags,
#                                   unsigned long buffer_size)
proc portRegister*(client: ClientP; portName: cstring; portType: cstring;
                   flags: culong; bufferSize: culong): PortP {.importc: "jack_port_register".}

# int jack_port_unregister (jack_client_t *client, jack_port_t *port)
proc portUnregister*(client: ClientP; port: PortP): cint {.importc: "jack_port_unregister".}

# void * jack_port_get_buffer (jack_port_t *port, jack_nframes_t)
proc portGetBuffer*(port: PortP; nframes: NFrames): pointer {.importc: "jack_port_get_buffer".}

# jack_uuid_t jack_port_uuid (const jack_port_t *port)
proc portUuid*(port: PortP): Uuid {.importc: "jack_port_uuid".}

# const char * jack_port_name (const jack_port_t *port)
proc portName*(port: PortP): cstring {.importc: "jack_port_name".}

# const char * jack_port_short_name (const jack_port_t *port)
proc portShortName*(port: PortP): cstring {.importc: "jack_port_short_name".}

# int jack_port_flags (const jack_port_t *port)
proc portFlags*(port: PortP): cint {.importc: "jack_port_flags".}

# const char * jack_port_type (const jack_port_t *port)
proc portType*(port: PortP): cstring {.importc: "jack_port_type".}

# jack_port_type_id_t jack_port_type_id (const jack_port_t *port)
proc portTypeId*(port: PortP): PortTypeId {.importc: "jack_port_type_id".}

# int jack_port_is_mine (const jack_client_t *client, const jack_port_t *port)
proc portIsMine*(client: ClientP; port: PortP): cint {.
    importc: "jack_port_is_mine".}

# int jack_port_connected (const jack_port_t *port)
proc portConnected*(port: PortP): cint {.importc: "jack_port_connected".}

# int jack_port_connected_to (const jack_port_t *port,
#                             const char *port_name)
proc portConnectedTo*(port: PortP; portName: cstring): cint {.importc: "jack_port_connected_to".}

# const char ** jack_port_get_connections (const jack_port_t *port)
#
# CAVEAT: The caller is responsible for calling jack_free() on any non-NULL returned value.
proc portGetConnections*(port: PortP): cstringArray {.importc: "jack_port_get_connections".}

# const char ** jack_port_get_all_connections (const jack_client_t *client,
#                                              const jack_port_t *port)
#
# CAVEAT: The caller is responsible for calling jack_free() on any non-NULL returned value.
proc portGetAllConnections*(client: ClientP; port: PortP): cstringArray {.
    importc: "jack_port_get_all_connections".}

# int jack_port_rename (jack_client_t* client, jack_port_t *port, const char *port_name)
proc portRename*(client: ClientP; port: PortP; portName: cstring): cint {.importc: "jack_port_rename".}

# int jack_port_set_alias (jack_port_t *port, const char *alias)
proc portSetAlias*(port: PortP; alias: cstring): cint {.importc: "jack_port_set_alias".}

# int jack_port_unset_alias (jack_port_t *port, const char *alias)
proc portUnsetAlias*(port: PortP; alias: cstring): cint {.importc: "jack_port_unset_alias".}

# int jack_port_get_aliases (const jack_port_t *port, char* const aliases[2])
proc portGetAliases*(port: PortP; aliases: array[2, cstring]): cint {.importc: "jack_port_get_aliases".}

#int jack_port_request_monitor (jack_port_t *port, int onoff)
proc portRequestMonitor*(port: PortP; onoff: cint): cint {.importc: "jack_port_request_monitor".}

# int jack_port_request_monitor_by_name (jack_client_t *client,
#                                        const char *port_name, int onoff)
proc portRequestMonitorByName*(client: ClientP; portName: cstring; onoff: cint): cint {.
    importc: "jack_port_request_monitor_by_name".}

# int jack_port_ensure_monitor (jack_port_t *port, int onoff)
proc portEnsureMonitor*(port: PortP; onoff: cint): cint {.
    importc: "jack_port_ensure_monitor".}

# int jack_port_monitoring_input (jack_port_t *port)
proc portMonitoringInput*(port: PortP): cint {.importc: "jack_port_monitoring_input".}

#[ DEPRECATED
int jack_port_tie (jack_port_t *src, jack_port_t *dst)
int jack_port_untie (jack_port_t *port)
int jack_port_set_name (jack_port_t *port, const char *port_name)
]#


# ------------------------------ Port Lookup ------------------------------

# const char ** jack_get_ports (jack_client_t *client,
#                               const char *port_name_pattern,
#                               const char *type_name_pattern,
#                               unsigned long flags)
#
# CAVEAT: The caller is responsible for calling jack_free() on any non-NULL returned value.
proc getPorts*(client: ClientP; portNamePattern: cstring;
               typeNamePattern: cstring; flags: culong): cstringArray {.importc: "jack_get_ports".}

# jack_port_t * jack_port_by_name (jack_client_t *client, const char *port_name)
proc portByName*(client: ClientP; portName: cstring): PortP {.importc: "jack_port_by_name".}

# jack_port_t * jack_port_by_id (jack_client_t *client, jack_port_id_t port_id)
proc portById*(client: ClientP; portId: PortId): PortP {.importc: "jack_port_by_id".}


# ------------------------------ Connections ------------------------------

# int jack_connect (jack_client_t *client,
#                   const char *source_port,
#                   const char *destination_port)
proc connect*(client: ClientP; srcPort: cstring; destPort: cstring): cint {.importc: "jack_connect".}

# int jack_disconnect (jack_client_t *client,
#                      const char *source_port,
#                      const char *destination_port)
proc disconnect*(client: ClientP; srcPort: cstring; destPort: cstring): cint {.importc: "jack_disconnect".}

# int jack_port_disconnect (jack_client_t *client, jack_port_t *port)
proc portDisconnect*(client: ClientP; port: PortP): cint {.importc: "jack_port_disconnect".}

# int jack_port_name_size(void)
proc portNameSize*(): cint {.importc: "jack_port_name_size".}

# int jack_port_type_size(void)
proc portTypeSize*(): cint {.importc: "jack_port_type_size".}

# size_t jack_port_type_get_buffer_size (jack_client_t *client, const char *port_type)
proc portTypeGetBufferSize*(client: ClientP; portType: cstring): csize_t {.
    importc: "jack_port_type_get_buffer_size".}


# --------------------------------- MIDI ----------------------------------

# jack_nframes_t jack_midi_get_event_count (void *port_buffer)
proc midiGetEventCount*(portBuffer: pointer): NFrames {.importc: "jack_midi_get_event_count".}

# int jack_midi_event_get (jack_midi_event_t *event, void *port_buffer, uint32_t event_index)
proc midiEventGet*(event: MidiEventP, portBuffer: pointer, eventIndex: uint32): cint {.
    importc: "jack_midi_event_get".}

# void jack_midi_clear_buffer (void *port_buffer)
proc midiClearBuffer*(portBuffer: pointer) {.importc: "jack_midi_clear_buffer".}

# size_t jack_midi_max_event_size (void *port_buffer)
proc midiMaxEventSize*(portBuffer: pointer): csize_t {.importc: "jack_midi_max_event_size".}

# jack_midi_data_t * jack_midi_event_reserve (void *port_buffer, jack_nframes_t time, size_t data_size)
proc midiEventReserve*(portBuffer: pointer, time: NFrames, dataSize: csize_t): ptr MidiData {.
    importc: "jack_midi_event_reserve".}

# int jack_midi_event_write (void *port_buffer, jack_nframes_t time, const jack_midi_data_t *data, size_t data_size)
proc midiEventWrite*(portBuffer: pointer, time: NFrames, data: ptr MidiData, dataSize: csize_t): int {.
    importc: "jack_midi_event_write".}

# uint32_t jack_midi_get_lost_event_count (void *port_buffer)
proc midiGetLostEventCount*(portBuffer: pointer): uint32 {.importc: "jack_midi_get_lost_event_count".}


# -------------------------------- Latency --------------------------------

# void jack_port_get_latency_range (jack_port_t *port, jack_latency_callback_mode_t mode, jack_latency_range_t *range)
proc portGetLatencyRange*(port: PortP; mode: LatencyCallbackMode; range: ptr LatencyRange) {.
    importc: "jack_port_get_latency_range".}

# void jack_port_set_latency_range (jack_port_t *port, jack_latency_callback_mode_t mode, jack_latency_range_t *range)
proc portSetLatencyRange*(port: PortP; mode: LatencyCallbackMode; range: ptr LatencyRange) {.
    importc: "jack_port_set_latency_range".}

# int jack_recompute_total_latencies (jack_client_t *)
proc recomputeTotalLatencies*(client: ClientP): cint {.importc: "jack_recompute_total_latencies".}

#[ DEPRECATED
jack_nframes_t jack_port_get_latency (jack_port_t *port)
jack_nframes_t jack_port_get_total_latency (jack_client_t *, jack_port_t *port)
void jack_port_set_latency (jack_port_t *port, jack_nframes_t)
int jack_recompute_total_latency (jack_client_t *, jack_port_t *port)
]#


# ----------------------------- Time handling -----------------------------

# jack_nframes_t jack_frames_since_cycle_start (const jack_client_t *)
proc framesSinceCycleStart*(client: ClientP): NFrames {.importc: "jack_frames_since_cycle_start".}

# jack_nframes_t jack_frame_time (const jack_client_t *)
proc frameTime*(client: ClientP): NFrames {.importc: "jack_frame_time".}

# jack_nframes_t jack_last_frame_time (const jack_client_t *client)
proc lastFrameTime*(client: ClientP): NFrames {.importc: "jack_last_frame_time".}

# int jack_get_cycle_times(const jack_client_t *client,
#                          jack_nframes_t *current_frames,
#                          jack_time_t    *current_usecs,
#                          jack_time_t    *next_usecs,
#                          float          *period_usecs)
proc getCycleTimes*(client: ClientP; currentFrames: ptr NFrames;
                    currentUsecs: ptr Time; nextUsecs: ptr Time;
                    periodUsecs: ptr cfloat): cint {.importc: "jack_get_cycle_times".}

# jack_time_t jack_frames_to_time(const jack_client_t *client, jack_nframes_t)
proc framesToTime*(client: ClientP; nframes: NFrames): Time {.importc: "jack_frames_to_time".}

# jack_nframes_t jack_time_to_frames(const jack_client_t *client, jack_time_t)
proc timeToFrames*(client: ClientP; time: Time): NFrames {.importc: "jack_time_to_frames".}

# jack_time_t jack_get_time(void)
proc getTime*(): Time {.importc: "jack_get_time".}


# ------------------------------- Transport -------------------------------

# int jack_release_timebase (jack_client_t *client)
proc releaseTimebase*(client: ClientP): cint {.importc: "jack_release_timebase".}

# int jack_set_sync_callback (jack_client_t *client, JackSyncCallback sync_callback, void *arg)
proc setSyncCallback*(client: ClientP; syncCallback: SyncCallback; arg: pointer = nil): cint {.
    importc: "jack_set_sync_callback".}

# int jack_set_sync_timeout (jack_client_t *client, jack_time_t timeout)
proc setSyncTimeout*(client: ClientP; timeout: Time): cint {.importc: "jack_set_sync_timeout".}

# int jack_set_timebase_callback (jack_client_t *client,
#                                 int conditional,
#                                 JackTimebaseCallback timebase_callback,
#                                 void *arg)
proc setTimebaseCallback*(client: ClientP; conditional: cint; timebaseCallback: TimebaseCallback;
                          arg: pointer = nil): cint {.
    importc: "jack_set_timebase_callback".}

# int jack_transport_locate (jack_client_t *client, jack_nframes_t frame)
proc transportLocate*(client: ClientP; frame: NFrames): cint {.importc: "jack_transport_locate".}

# jack_transport_state_t jack_transport_query (const jack_client_t *client, jack_position_t *pos)
proc transportQuery*(client: ClientP; pos: PositionP): TransportState {.importc: "jack_transport_query".}

# jack_nframes_t jack_get_current_transport_frame (const jack_client_t *client)
proc getCurrentTransportFrame*(client: ClientP): NFrames {.importc: "jack_get_current_transport_frame".}

# int jack_transport_reposition (jack_client_t *client, const jack_position_t *pos)
proc transportReposition*(client: ClientP; pos: PositionP): cint {.importc: "jack_transport_reposition".}

# void jack_transport_start (jack_client_t *client)
proc transportStart*(client: ClientP) {.importc: "jack_transport_start".}

# void jack_transport_stop (jack_client_t *client)
proc transportStop*(client: ClientP) {.importc: "jack_transport_stop".}

#[ DEPRECATED
void jack_get_transport_info (jack_client_t *client, jack_transport_info_t *tinfo)
void jack_set_transport_info (jack_client_t *client, jack_transport_info_t *tinfo)
]#

# ----------------------------- Ringbuffers -------------------------------

# jack_ringbuffer_t *jack_ringbuffer_create (size_t sz)
proc ringbufferCreate*(sz: csize_t): RingbufferP {.importc: "jack_ringbuffer_create".}

# void jack_ringbuffer_free (jack_ringbuffer_t *rb)
proc ringbufferFree*(rb: RingbufferP) {.importc: "jack_ringbuffer_free".}

# void jack_ringbuffer_get_read_vector (const jack_ringbuffer_t *rb, jack_ringbuffer_data_t *vec)
proc ringbufferGetReadVector*(rb: RingbufferP, vec: var RingbufferDataP) {.importc: "jack_ringbuffer_get_read_vector".}

# void jack_ringbuffer_get_write_vector (const jack_ringbuffer_t *rb, jack_ringbuffer_data_t *vec)
proc ringbufferGetWriteVector*(rb: RingbufferP, vec: var RingbufferDataP) {.importc: "jack_ringbuffer_get_write_vector".}

# size_t jack_ringbuffer_read (jack_ringbuffer_t *rb, char *dest, size_t cnt)
proc ringbufferRead*(rb: RingbufferP, dest: cstring, cnt: csize_t): csize_t {.importc: "jack_ringbuffer_read".}

# size_t jack_ringbuffer_peek (jack_ringbuffer_t *rb, char *dest, size_t cnt)
proc ringbufferPeek*(rb: RingbufferP, dest: cstring, cnt: csize_t): csize_t {.importc: "jack_ringbuffer_peek".}

# void jack_ringbuffer_read_advance (jack_ringbuffer_t *rb, size_t cnt)
proc ringbufferReadAdvance*(rb: RingbufferP, cnt: csize_t) {.importc: "jack_ringbuffer_read_advance".}

# size_t jack_ringbuffer_read_space (const jack_ringbuffer_t *rb)
proc ringbufferReadSpace*(rb: RingbufferP): csize_t {.importc: "jack_ringbuffer_read_space".}

# int jack_ringbuffer_mlock (jack_ringbuffer_t *rb)
proc ringbufferMlock*(rb: RingbufferP): int {.importc: "jack_ringbuffer_mlock".}

# void jack_ringbuffer_reset (jack_ringbuffer_t *rb)
proc ringbufferReset*(rb: RingbufferP) {.importc: "jack_ringbuffer_reset".}

# size_t jack_ringbuffer_write (jack_ringbuffer_t *rb, const char *src, size_t cnt)
proc ringbufferWrite*(rb: RingbufferP, src: cstring, cnt: csize_t): csize_t {.importc: "jack_ringbuffer_write".}

# void jack_ringbuffer_write_advance (jack_ringbuffer_t *rb, size_t cnt)
proc ringbufferWriteAdvance*(rb: RingbufferP, cnt: csize_t) {.importc: "jack_ringbuffer_write_advance".}

# size_t jack_ringbuffer_write_space (const jack_ringbuffer_t *rb)
proc ringbufferWriteSpace*(rb: RingbufferP): csize_t {.importc: "jack_ringbuffer_write_space".}

# ------------------------------- Metadata --------------------------------

# int jack_set_property (jack_client_t*, jack_uuid_t subject, const char* key, const char* value, const char* type)
proc setProperty*(client: ClientP, subject: Uuid, key, value, `type`: cstring): cint {.importc: "jack_set_property".}

# int jack_get_property (jack_uuid_t subject, const char* key, char** value, char** type)
proc getProperty*(subject: Uuid, key: cstring, value, `type`: ptr cstring): cint {.importc: "jack_get_property".}

# void jack_free_description (jack_description_t* desc, int free_description_itself)
proc freeDescription*(desc: DescriptionP, freeDescriptionItself: cint) {.importc: "jack_free_description".}

# int jack_get_properties (jack_uuid_t subject, jack_description_t* desc)
proc getProperties*(subject: Uuid, desc: DescriptionP): cint {.importc: "jack_get_properties".}

# int jack_get_all_properties (jack_description_t** descs)
proc getAllProperties*(descs: var ptr UncheckedArray[Description]): cint {.importc: "jack_get_all_properties".}

# int jack_remove_property (jack_client_t* client, jack_uuid_t subject, const char* key)
proc removeProperty*(client: ClientP, subject: Uuid): cint {.importc: "jack_remove_property".}

# int jack_remove_properties (jack_client_t* client, jack_uuid_t subject)
proc removeProperties*(client: ClientP, subject: Uuid): cint {.importc: "jack_remove_properties".}

# int jack_remove_all_properties (jack_client_t* client)
proc removeAllProperties*(client: ClientP): cint {.importc: "jack_remove_all_properties".}

# int jack_set_property_change_callback (jack_client_t* client, JackPropertyChangeCallback callback, void* arg)
proc setPropertyChangeCallback*(client: ClientP, callback: PropertyChangeCallback, arg: pointer = nil): cint {.
    importc: "jack_set_property_change_callback".}


# ---------------------------- Error handling -----------------------------

proc setErrorFunction*(errorCallback: ErrorCallback) {.importc: "jack_set_error_function".}

proc setInfoFunction*(infoCallback: InfoCallback) {.importc: "jack_set_info_function".}

{.pop.}


# --------------------------- Helper functions ----------------------------

proc getJackStatusErrorString*(status: cint): string =
    # Get JACK error status as string.
    if status == Success:
        return ""

    if status == Failure:
        # Only include this generic message if no other error status is set
        result = "Overall operation failed"
    if (status and InvalidOption) > 0:
        result.add("\nThe operation contained an invalid and unsupported option")
    if (status and NameNotUnique) > 0:
        result.add("\nThe desired client name was not unique")
    if (status and ServerStarted) > 0:
        result.add("\nThe JACK server was started as a result of this operation")
    if (status and ServerFailed) > 0:
        result.add("\nUnable to connect to the JACK server")
    if (status and ServerError) > 0:
        result.add("\nCommunication error with the JACK server")
    if (status and NoSuchClient) > 0:
        result.add("\nRequested client does not exist")
    if (status and LoadFailure) > 0:
        result.add("\nUnable to load internal client")
    if (status and InitFailure) > 0:
        result.add("\nUnable to initialize client")
    if (status and ShmFailure) > 0:
        result.add("\nUnable to access shared memory")
    if (status and VersionError) > 0:
        result.add("\nClient's protocol version does not match")
    if (status and BackendError) > 0:
        result.add("\nBackend Error")
    if (status and ClientZombie) > 0:
        result.add("\nClient is being shutdown against its will")
