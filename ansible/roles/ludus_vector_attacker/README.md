# ludus_vector_attacker

Installs auditd JSON production and the Kali Vector edge agent. Vector tails
Kali audit records, Caldera operation exports, and its own internal logs, then
sends source-labeled native events to the central Vector aggregator using the
Vector protocol with acknowledgements and a blocking disk buffer.

The attacker no longer writes directly to ClickHouse and holds no ClickHouse
credentials. Experiment-run identity belongs to the run controller and Caldera
export records, not a service-start environment variable.
