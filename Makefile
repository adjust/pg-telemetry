EXTENSION = pgtelemetry
DATA = extension/*

ifeq ($(PG_CONFIG),)
PG_CONFIG = pg_config
endif
REGRESS = definitions
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
