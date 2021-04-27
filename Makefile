EXTENSION = pgtelemetry
DATA = extension/*

ifeq ($(PG_CONFIG),)
PG_CONFIG = pg_config
endif
REGRESS = definitions
REGRESS_OPTS = --load-extension=pg_stat_statements --temp-config=extras/regression/postgresql.conf --temp-instance=tmp-regression-test
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
