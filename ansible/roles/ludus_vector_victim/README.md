# ludus_vector_victim

Installs the victim-side Vector edge agent. It tails Kubernetes API audit JSON,
Tetragon JSON export, selected CRI container logs, and Vector's own internal
logs. Events are preserved at the edge, labeled with their native source type,
checkpointed in Vector's data directory, buffered on disk, and delivered with
acknowledgements to the central Vector aggregator.

This role does not replace Kubernetes audit or Tetragon; those utilities produce
the authoritative source records that Vector transports. Tetragon's optional
stdout-export sidecar is disabled and its pod log paths are explicitly excluded
from the generic CRI source, preventing full Tetragon JSON from being stored a
second time as `container_log` evidence.
