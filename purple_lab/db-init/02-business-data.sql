CREATE TABLE employees (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    email TEXT NOT NULL,
    department TEXT NOT NULL,
    role TEXT NOT NULL
);

INSERT INTO employees (name, email, department, role) VALUES
('Ola Nordmann', 'ola.nordmann@bedriften.no', 'IT', 'Systemadministrator'),
('Kari Hansen', 'kari.hansen@bedriften.no', 'Økonomi', 'Regnskapsansvarlig'),
('Per Berg', 'per.berg@bedriften.no', 'Ledelse', 'Daglig leder'),
('Anne Lund', 'anne.lund@bedriften.no', 'HR', 'HR-rådgiver');

CREATE TABLE internal_notes (
    id SERIAL PRIMARY KEY,
    title TEXT NOT NULL,
    content TEXT NOT NULL
);

INSERT INTO internal_notes (title, content) VALUES
('Filserver-migrering', 'Felles dokumenter er flyttet til \\filserver\Public. Sensitive dokumenter ligger på separat deling med begrenset tilgang.'),
('Driftsnotat', 'Drifts-PC benyttes til administrasjon av interne tjenester og har tilgang til både backend-nett og internt nett.'),
('Midlertidig rutine', 'Gamle admin-passord skal fases ut etter migrering. Ikke legg passord i kode eller dokumenter.'),
('Økonomidata', 'Lønnslister og kundekontrakter skal kun være tilgjengelig fra interne maskiner med administrative rettigheter.');
