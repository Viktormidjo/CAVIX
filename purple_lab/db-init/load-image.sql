INSERT INTO images (data)
SELECT pg_read_binary_file('/docker-entrypoint-initdb.d/sample.png');
