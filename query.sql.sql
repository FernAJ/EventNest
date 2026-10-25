CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(150) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    role VARCHAR(20) NOT NULL DEFAULT 'student'
);

CREATE TABLE events (
    id SERIAL PRIMARY KEY,
    title VARCHAR(150) NOT NULL,
    description TEXT,
    date DATE NOT NULL,
    start_time TIME,
    end_time TIME,
    venue VARCHAR(150),
    status VARCHAR(30) DEFAULT 'UPCOMING',
    created_by INTEGER REFERENCES users(id)
);

INSERT INTO users (name, email, password, role)
VALUES
('Admin User', 'admin@eventnest.com', 'test123', 'admin'),
('Student User', 'student@eventnest.com', 'test123', 'student');

INSERT INTO events
(title, description, date, start_time, end_time, venue, status, created_by)
VALUES
(
    'College Foundation Day',
    'Annual college foundation celebration',
    '2026-10-20',
    '09:00',
    '17:00',
    'University Gym',
    'UPCOMING',
    1
);