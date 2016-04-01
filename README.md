# rrarbiter

A simple non-preemptive round-robin arbiter.

It interfaces with the requester using 3 signals: valid (a request is initiated), ready (the request is granted) and data (the requested data).
It interacts with the next stage using three signals (just like the requester): valid, ready and data.
It can be configured to support an arbitrary number of requesters and arbitrarily wide request data.

Owing to a modular implementation, the entire arbiter needn't be rewritten to implement another arbitration algorithm.
