# jacket

A [Nim] wrapper for the JACK Audio Connection Kit ([JACK]) client side [C API]
aka **libjack**.


## Project status

This software is in *beta status*.

The majority of JACK client API functions have been wrapped and are functional
(see[examples]), but some API parts (e.g. threading) still need wrapping.
Others, like the server control or the deprecated session API, will probably
not be covered by these bindings. While this project is in beta stage, symbol
names may still be changed and things moved around before the first stable
release.


## Installation

* Clone this repository.
* Change into the `jacket` directory.
* Run [`nimble install`] (or `nimble develop`).
* Build the [examples] with `nimble examples`.

   (Some examples need `--threads:on` with Nim < 2.0).


## Usage

Here is a very minimal JACK client application, which just passes audio through
from its single input port to its output port. Any error checking and handling
has been omitted for brevity's sake. See the files in the [examples] directory
for more robust example code.

```nim
import std/os
import system/ansi_c
import jacket

var
    status: cint
    exitSignalled = false
    inpPort, outPort: Port

type SampleBuffer = ptr UncheckedArray[DefaultAudioSample]

proc signalCb(sig: cint) {.noconv.} =
    exitSignalled = true

proc shutdownCb(arg: pointer = nil) {.cdecl.} =
    exitSignalled = true

proc processCb(nFrames: NFrames, arg: pointer): cint {.cdecl.} =
    let inpbuf = cast[SampleBuffer](portGetBuffer(inpPort, nFrames))
    let outbuf = cast[SampleBuffer](portGetBuffer(outPort, nFrames))
    # copy samples from input to output buffer
    for i in 0 ..< nFrames:
        outbuf[i] = inpbuf[i]

# Create JACK Client ptr
var jackClient = clientOpen("passthru", NullOption, status.addr)
# Register audio input and output ports
inpPort = jackClient.portRegister("in_1", JackDefaultAudioType, PortIsInput, 0)
outPort = jackClient.portRegister("out_1", JackDefaultAudioType, PortIsOutput, 0)
# Set JACK callbacks
jackClient.onShutdown(shutdownCb)
jackClient.setProcessCallback(processCb, nil)
# Handle POSIX signals
c_signal(SIGINT, signalCb)
c_signal(SIGTERM, signalCb)
# Activate JACK client ...
jackClient.activate()

while not exitSignalled:
    sleep(50)

jackClient.clientClose()
```


## License

This software is released under the *MIT License*. See the file
[LICENSE.md](./LICENSE.md) for more information.

Please note that the JACK client library (libjack), which this project wraps,
is licensed under the [LGPL-2.1]. This wrapper does not statically or
dynamically link to libjack at build time, but only loads it via `dynlib` at
run-time.

Software using this wrapper is, in the opinion of its author, not considered a
derivative work of libjack and not required to be released under the LGPL, but
no guarantees are made in this regard and users are advised to employ
professional legal counsel when in doubt.


## Author

*jacket* is written by [Christopher Arndt].


[C API]: https://jackaudio.org/api/
[Christopher Arndt]: mailto:info@chrisarndt.de
[examples]: ./examples
[JACK]: https://jackaudio.org/
[LGPL-2.1]: https://spdx.org/licenses/LGPL-2.1-or-later.html
[`nimble install`]: https://github.com/nim-lang/nimble#nimble-usage
[Nim]: https://nim-lang.org/
