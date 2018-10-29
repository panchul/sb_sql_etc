-- MY OWN TEST, small table with ints
CREATE TABLE myownints1 (val int);

INSERT INTO myownints1(val)
SELECT *
FROM generate_series(0, 4);

SELECT * FROM myownints1;

SELECT median(val) FROM myownints1;

-- MY OWN TEST, medium table with ints
CREATE TABLE myownints_medium (val int);

INSERT INTO myownints_medium(val)
SELECT *
FROM generate_series(0, 10);

SELECT * FROM myownints_medium;

SELECT median(val) FROM myownints_medium;

-- MY OWN TEST, large table with ints
CREATE TABLE myownints2 (val int);

INSERT INTO myownints2(val)
SELECT *
FROM generate_series(0, 100000);

/* it's too large
SELECT * FROM myownints2; 
*/

SELECT median(val) FROM myownints2;

-- Now, working part of the other test
CREATE TABLE intvals(val int, color text);

-- Test empty table
SELECT median(val) FROM intvals;

-- Integers with odd number of values
INSERT INTO intvals VALUES
       (1, 'a'),
       (2, 'c'),
       (9, 'b'),
       (7, 'c'),
       (2, 'd'),
       (-3, 'd'),
       (2, 'e');

SELECT * FROM intvals ORDER BY val;
SELECT median(val) FROM intvals;

/*
-- Integers with NULLs and even number of values
INSERT INTO intvals VALUES
       (99, 'a'),
       (NULL, 'a'),
       (NULL, 'e'),
       (NULL, 'b'),
       (7, 'c'),
       (0, 'd');

SELECT * FROM intvals ORDER BY val;
SELECT median(val) FROM intvals;
*/

-- Text values
CREATE TABLE textvals(val text, color int);

INSERT INTO textvals VALUES
       ('erik', 1),
       ('mat', 3),
       ('rob', 8),
       ('david', 9),
       ('lee', 2);

SELECT * FROM textvals ORDER BY val;
SELECT median(val) FROM textvals;



-- Test large table with timestamps
CREATE TABLE timestampvals (val timestamptz);

INSERT INTO timestampvals(val)
SELECT TIMESTAMP 'epoch' + (i * INTERVAL '1 second')
FROM generate_series(0, 100000) as T(i);

SELECT median(val) FROM timestampvals;

