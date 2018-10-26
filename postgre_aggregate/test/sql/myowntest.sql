-- MY OWN TEST, small table with ints
CREATE TABLE myownints1 (val int);

INSERT INTO myownints1(val)
SELECT *
FROM generate_series(0, 4);

SELECT * FROM myownints1;

SELECT median(val) FROM myownints1;

-- MY OWN TEST, large table with ints
CREATE TABLE myownints2 (val int);

INSERT INTO myownints2(val)
SELECT *
FROM generate_series(0, 100000);

/* it's too large
SELECT * FROM myownints2; 
*/

SELECT median(val) FROM myownints2;

