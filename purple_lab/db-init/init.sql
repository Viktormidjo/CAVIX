CREATE TABLE comments (
    id SERIAL PRIMARY KEY,
    text TEXT
);

INSERT INTO comments (text) VALUES
('Hei! Dette er en kommentar.'),
('Velkommen til bedriften.no!'),
('Dette er en test.'),
('Systemet fungerer.'),
('Docker-compose er kult!');

CREATE TABLE images (
    id SERIAL PRIMARY KEY,
    data BYTEA
);
