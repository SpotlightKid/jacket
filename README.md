# jacket

A [Nim] wrapper for the [JACK] [C API]


## Project status

This software is in *alpha status* and has no official release yet.

The basic JACK APIs (client lifecycle, ports, callbacks) have been wrapped and
are functional (see [examples]), but MIDI, transport and meta-data APIs still 
need wrapping. Also, symbol names may still be changed and things moved around
before the first public release.

Also, I plan to add a higher-level abstraction on top of the direct mapping
from Nim procs and types to C functions and types, probably in the form of
a JACK client object, which takes care of creating a JACK client instance,
registering ports and setting up all the callbacks necessary for a well-behaved
JACK application.


## Installation

* Clone this repository.
* Change into the `jacket` directory.
* Run [`nimble install`] (or `nimble develop`).
* Run the examples with `nim compile --run examples/<example>.nim`.


## License

This software is released under the *MIT License*. See the [LICENSE](./LICENSE)
file for more information.


[`nimble install`]: https://github.com/nim-lang/nimble#nimble-usage
[C API]: https://jackaudio.org/api/
[examples]: ./examples
[JACK]: https://jackaudio.org/
[Nim]: https://nim-lang.org/
