-- =====================================================================
--  EventNest - PostgreSQL database (schema + sample data)
--  Ateneo de Zamboanga University | Web Systems and Technologies
--
--  Test accounts (also listed in README.md):
--    Admin : admin@eventnest.com      / Admin@123
--    User  : student@eventnest.com    / User@123
--    User  : organizer@eventnest.com  / User@123
--
--  All timestamps are campus time (Asia/Manila), stored without a time zone.
--  Sample event dates are relative to the moment of import, so the
--  Current / Upcoming / Archive views always have data to show.
--  Safe to run repeatedly: it drops and recreates the tables.
-- =====================================================================

-- Needed for the "no overlapping approved events at one venue" constraint.
CREATE EXTENSION IF NOT EXISTS btree_gist;

DROP TABLE IF EXISTS notifications CASCADE;
DROP TABLE IF EXISTS events CASCADE;
DROP TABLE IF EXISTS venues CASCADE;
DROP TABLE IF EXISTS users CASCADE;

CREATE TABLE users (
  user_id       SERIAL       PRIMARY KEY,
  email         VARCHAR(255) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  full_name     VARCHAR(120) NOT NULL,
  role          VARCHAR(10)  NOT NULL DEFAULT 'User' CHECK (role IN ('Admin','User')),
  created_at    TIMESTAMP    NOT NULL DEFAULT (NOW() AT TIME ZONE 'Asia/Manila')
);

CREATE TABLE venues (
  venue_id SERIAL       PRIMARY KEY,
  name     VARCHAR(120) NOT NULL UNIQUE,
  location VARCHAR(255),
  capacity INTEGER      CHECK (capacity IS NULL OR capacity > 0)
);

CREATE TABLE events (
  event_id             SERIAL       PRIMARY KEY,
  requested_by         INTEGER      NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  reviewed_by          INTEGER      REFERENCES users(user_id) ON DELETE SET NULL,
  venue_id             INTEGER      NOT NULL REFERENCES venues(venue_id) ON DELETE RESTRICT,
  title                VARCHAR(200) NOT NULL,
  description          TEXT,
  category             VARCHAR(80)  NOT NULL DEFAULT 'General',
  hosting_organization VARCHAR(150) NOT NULL DEFAULT 'N/A',
  target_audience      VARCHAR(150) NOT NULL DEFAULT 'All',
  start_datetime       TIMESTAMP    NOT NULL,
  end_datetime         TIMESTAMP    NOT NULL,
  status               VARCHAR(10)  NOT NULL DEFAULT 'Pending'
                       CHECK (status IN ('Pending','Approved','Rejected','Completed')),
  reviewed_at          TIMESTAMP,
  rejection_reason     TEXT,
  created_at           TIMESTAMP    NOT NULL DEFAULT (NOW() AT TIME ZONE 'Asia/Manila'),
  CONSTRAINT events_end_after_start CHECK (end_datetime > start_datetime),
  -- Business rule: one venue cannot host two approved events at overlapping times.
  CONSTRAINT events_no_venue_overlap EXCLUDE USING gist (
    venue_id WITH =,
    tsrange(start_datetime, end_datetime) WITH &&
  ) WHERE (status = 'Approved')
);
CREATE INDEX idx_events_status_start ON events(status, start_datetime);
CREATE INDEX idx_events_requested_by ON events(requested_by);

CREATE TABLE notifications (
  notification_id SERIAL    PRIMARY KEY,
  user_id         INTEGER   NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  event_id        INTEGER   REFERENCES events(event_id) ON DELETE SET NULL,
  message         TEXT      NOT NULL,
  is_read         BOOLEAN   NOT NULL DEFAULT FALSE,
  created_at      TIMESTAMP NOT NULL DEFAULT (NOW() AT TIME ZONE 'Asia/Manila')
);
CREATE INDEX idx_notifications_user ON notifications(user_id, is_read);

-- ---------------------------- SAMPLE DATA ----------------------------
-- Password hashes are scrypt (see src/security.js).
INSERT INTO users (email, password_hash, full_name, role) VALUES
 ('admin@eventnest.com',     'scrypt$16384$8$1$IVs9Fkl9+HSlBaDCXL7flw==$Q6+guXxTRS87WFRoKOKgTlAASLPlq+NCMaie07V+aTgzKyZfplkWH6iJfSc7Cf9BZpkx9dHeD4pzwdQScFDmAw==', 'System Administrator', 'Admin'),
 ('student@eventnest.com',   'scrypt$16384$8$1$VmLqLxttU2kbfgAQwCG6ig==$kKznOEx6hh//mBp7+aO/5rssN4V1Ne5xhaYbSnn9YWbgvf375tQwctFChZbi4+W0fQ8bgD8it79G1m0wlpQtHw==', 'Sample Student', 'User'),
 ('organizer@eventnest.com', 'scrypt$16384$8$1$VmLqLxttU2kbfgAQwCG6ig==$kKznOEx6hh//mBp7+aO/5rssN4V1Ne5xhaYbSnn9YWbgvf375tQwctFChZbi4+W0fQ8bgD8it79G1m0wlpQtHw==', 'Sample Organizer', 'User');

INSERT INTO venues (name, location, capacity) VALUES
 ('University Gymnasium',     'Main Campus',          1500),
 ('Social Hall',              'Administration Bldg.',  400),
 ('Mini Theater',             'Library Bldg.',         150),
 ('Quadrangle',               'Main Campus',          2000),
 ('Conference Room',          'CSITE Bldg.',            40);

-- d(n) = today (Manila) + n days at 00:00
INSERT INTO events (requested_by, reviewed_by, venue_id, title, description, category, hosting_organization, target_audience,
                    start_datetime, end_datetime, status, reviewed_at) VALUES
 (3,1,1,'Intramurals Opening Ceremony','Parade of teams and opening program.','Sports','Student Affairs Office','All students',
   date_trunc('day', NOW() AT TIME ZONE 'Asia/Manila') - interval '30 days' + interval '08:00',
   date_trunc('day', NOW() AT TIME ZONE 'Asia/Manila') - interval '30 days' + interval '12:00','Completed', NOW()),
 (3,1,2,'College Foundation Day','Annual celebration of the college.','Institutional','CSITE','Faculty and students',
   date_trunc('day', NOW() AT TIME ZONE 'Asia/Manila') - interval '14 days' + interval '09:00',
   date_trunc('day', NOW() AT TIME ZONE 'Asia/Manila') - interval '14 days' + interval '17:00','Completed', NOW()),
 (2,1,3,'Leadership Seminar','Seminar for student leaders.','Academic','Student Council','Student leaders',
   date_trunc('day', NOW() AT TIME ZONE 'Asia/Manila') - interval '7 days' + interval '13:00',
   date_trunc('day', NOW() AT TIME ZONE 'Asia/Manila') - interval '7 days' + interval '16:00','Completed', NOW()),
 (3,1,3,'Research Colloquium','Presentation of ongoing student research.','Academic','Research Office','Faculty and students',
   (NOW() AT TIME ZONE 'Asia/Manila') - interval '1 hour',
   (NOW() AT TIME ZONE 'Asia/Manila') + interval '2 hours','Approved', NOW()),
 (3,1,1,'Career Fair','Partner companies recruit graduating students.','Career','Career Services','Graduating students',
   date_trunc('day', NOW() AT TIME ZONE 'Asia/Manila') + interval '2 days 09:00',
   date_trunc('day', NOW() AT TIME ZONE 'Asia/Manila') + interval '2 days 16:00','Approved', NOW()),
 (2,1,2,'Cultural Night','Showcase of campus cultural groups.','Socio-cultural','Cultural Committee','All students',
   date_trunc('day', NOW() AT TIME ZONE 'Asia/Manila') + interval '5 days 18:00',
   date_trunc('day', NOW() AT TIME ZONE 'Asia/Manila') + interval '5 days 21:00','Approved', NOW()),
 (3,1,4,'Organization Recognition Assembly','Recognition of accredited student organizations.','Institutional','Student Affairs Office','Organization officers',
   date_trunc('day', NOW() AT TIME ZONE 'Asia/Manila') + interval '9 days 09:00',
   date_trunc('day', NOW() AT TIME ZONE 'Asia/Manila') + interval '9 days 12:00','Approved', NOW()),
 (2,NULL,5,'Coding Bootcamp','Hands-on programming workshop.','Academic','Computer Science Society','CS students',
   date_trunc('day', NOW() AT TIME ZONE 'Asia/Manila') + interval '4 days 09:00',
   date_trunc('day', NOW() AT TIME ZONE 'Asia/Manila') + interval '4 days 17:00','Pending', NULL),
 (3,NULL,1,'Blood Donation Drive','Community blood donation.','Community','Red Cross Youth','All',
   date_trunc('day', NOW() AT TIME ZONE 'Asia/Manila') + interval '6 days 08:00',
   date_trunc('day', NOW() AT TIME ZONE 'Asia/Manila') + interval '6 days 12:00','Pending', NULL),
 (2,1,1,'Movie Marathon','Film screening.','Socio-cultural','Film Club','Students',
   date_trunc('day', NOW() AT TIME ZONE 'Asia/Manila') + interval '2 days 14:00',
   date_trunc('day', NOW() AT TIME ZONE 'Asia/Manila') + interval '2 days 18:00','Rejected', NOW());
UPDATE events SET rejection_reason = 'Venue is reserved for the Career Fair.' WHERE title = 'Movie Marathon';

INSERT INTO notifications (user_id, event_id, message) VALUES
 (1, 8,  'New event request: "Coding Bootcamp" is waiting for review.'),
 (1, 9,  'New event request: "Blood Donation Drive" is waiting for review.'),
 (3, 5,  'Your event "Career Fair" was approved.'),
 (2, 6,  'Your event "Cultural Night" was approved.'),
 (2, 10, 'Your event "Movie Marathon" was rejected: Venue is reserved for the Career Fair.');
