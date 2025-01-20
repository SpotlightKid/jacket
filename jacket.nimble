# Package

version       = "0.2.0"
author        = "Christopher Arndt"
description   = "A Nim wrapper for the JACK Audio Connection Kit client-side C API aka libjack"
license       = "MIT"

srcDir = "src"

# Dependencies

requires "nim >= 1.6.0"

let examples = @[
    "info",
    "list_all_properties",
    "midi_print",
    "midi_print_ringbuffer",
    "midi_print_thread",
    "midi_print_threading",
    "passthru",
    "port_connect_cb",
    "port_register",
    "ringbuffer",
    "sine",
    "transport_query",
]

task examples, "Build examples (release)":
    for example in examples:
        echo "Building example 'jacket_" & example & "'..."
        selfExec("compile -d:release -d:strip examples/jacket_" & example & ".nim")

task examples_debug, "Build examples (debug)":
    for example in examples:
        echo "Building example 'jacket_" & example & "' (debug)..."
        selfExec("compile examples/jacket_" & example & ".nim")
