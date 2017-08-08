EXTENSION = pgtelemetry
DATA = extension/*

PG_CONFIG = pg_config
REGRESS = definitions
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
