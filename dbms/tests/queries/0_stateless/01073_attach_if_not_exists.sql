CREATE TABLE t (a Int) ENGINE = Log;
ATTACH TABLE t; -- { serverError 57 }
ATTACH TABLE IF NOT EXISTS t;
DETACH TABLE t;
ATTACH TABLE IF NOT EXISTS t;
EXISTS TABLE t;
