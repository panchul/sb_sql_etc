CREATE TABLE test1 (i int4, t text, b bytea);

INSERT INTO test1 values (1, 'joe''s place', '\000\001\002\003\004');
INSERT INTO test1 values (2, 'ho there', '\004\003\002\001\000');

/*
 * The expected output is:
 *
 * tuple 0: got
 *  i = (4 bytes) 1
 *  t = (11 bytes) 'joe's place'
 *  b = (5 bytes) \000\001\002\003\004
 *
 * tuple 0: got
 *  i = (4 bytes) 2
 *  t = (8 bytes) 'ho there'
 *  b = (5 bytes) \004\003\002\001\000
 */
