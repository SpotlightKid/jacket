# TODO


## Threading API

Still needs to be wrapped. How to handle `jack_native_thread_t` type?


## Internal Clients

Jack 1 and JACK 2 are disagreeing on the signatures of the functions for
loading and getting a handle for internal clients:

* https://github.com/jackaudio/jack2/blob/develop/common/jack/intclient.h#L66
* https://github.com/jackaudio/headers/blob/2bfa5069718ca4f4dc091e0be845958f2d8a5ba8/intclient.h#L69
* https://jackaudio.org/api/intclient_8h.html#a176a2daf66c8777eb1a845068fd7a822


## Higher level abstraction

Add a higher-level abstraction on top of the direct mapping from Nim procs and
types to C functions and types, in the form of a JACK client object, which
takes care of creating a JACK client instance, registering ports and setting up
all the callbacks necessary for a well-behaved JACK application.
