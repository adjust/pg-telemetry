EXTENSION = pgtelemetry
DATA = extension/*

PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
