#!/bin/sh

#set -e

CURRENT_DIR=$PWD
# locate
if [ -z "$BASH_SOURCE" ]; then
    SCRIPT_DIR=`dirname "$(readlink -f $0)"`
elif [ -e '/bin/zsh' ]; then
    F=`/bin/zsh -c "print -lr -- $BASH_SOURCE(:A)"`
    SCRIPT_DIR=`dirname $F`
elif [ -e '/usr/bin/realpath' ]; then
    F=`/usr/bin/realpath $BASH_SOURCE`
    SCRIPT_DIR=`dirname $F`
else
    F=$BASH_SOURCE
    while [ -h "$F" ]; do F="$(readlink $F)"; done
    SCRIPT_DIR=`dirname $F`
fi

cd $SCRIPT_DIR

REL_BIN='libsql-sqlite3/libsql'
[ -e "$REL_BIN" ] || cargo xtask build --release

build_bottomless() {
    cd bottomless
    LIBSQL_DIR=$SCRIPT_DIR/libsql-sqlite3 make release
    cd - > /dev/null
}

gen_smoke_sql() {
cat << EOF
.bail on
.echo on
.load ./target/release/bottomless
.open file:target/test.db?wal=bottomless
PRAGMA page_size=65536;
PRAGMA journal_mode=wal;
PRAGMA page_size;
DROP TABLE IF EXISTS test;
CREATE TABLE test(v);
INSERT INTO test VALUES (42);
INSERT INTO test VALUES (zeroblob(8193));
INSERT INTO test VALUES ('hey');
.mode column

BEGIN;
INSERT INTO test VALUES ('presavepoint');
INSERT INTO test VALUES (zeroblob(1600000));
INSERT INTO test VALUES (zeroblob(1600000));
INSERT INTO test VALUES (zeroblob(2400000));
SAVEPOINT test1;
INSERT INTO test VALUES (43);
INSERT INTO test VALUES (zeroblob(2000000));
INSERT INTO test VALUES (zeroblob(2000000));
INSERT INTO test VALUES (zeroblob(2000000));
INSERT INTO test VALUES ('heyyyy');
ROLLBACK TO SAVEPOINT test1;
COMMIT;

BEGIN;
INSERT INTO test VALUES (3.16);
INSERT INTO test VALUES (zeroblob(1000000));
INSERT INTO test VALUES (zeroblob(1000000));
INSERT INTO test VALUES (zeroblob(1000000));
ROLLBACK;

PRAGMA wal_checkpoint(FULL);

INSERT INTO test VALUES (3.14);
INSERT INTO test VALUES (zeroblob(31400));

PRAGMA wal_checkpoint(PASSIVE);
PRAGMA wal_checkpoint(PASSIVE);

INSERT INTO test VALUES (997);

SELECT v, length(v) FROM test;
.exit

EOF
}

[ -e target/release/bottomless.so ] || build_bottomless || exit 1

. .env
gen_smoke_sql | ./$REL_BIN
