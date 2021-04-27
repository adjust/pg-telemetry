EXTENSION = pgtelemetry
DATA = extension/*

ifeq ($(PG_CONFIG),)
PG_CONFIG = pg_config
endif
REGRESS = definitions
REGRESS_OPTS = --load-extension=pg_stat_statements
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
