# ludus_vector_router

Installs the router-side Vector edge agent. It tails Zeek JSON logs, preserves
native records and `_path`, and sends them with disk buffering and delivery
acknowledgements to the central Vector aggregator. It also forwards the small
JSON manifest emitted when a run-bounded PCAP is sealed.

PCAP files are deliberately not transported through Vector. The router evidence
stage retains the packet artifact on the router and sends only its hash, size,
capture bounds, run identity, Zeek replay metadata, Zeek events, and Vector
health records.
