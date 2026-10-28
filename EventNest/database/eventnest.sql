-- =====================================================================
--  EventNest - PostgreSQL database (schema + sample data: 26 venues, 10 users, 41 events, 41 notifications)
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
-- Every non-admin account below uses the password  User@123
INSERT INTO users (email, password_hash, full_name, role) VALUES
 ('admin@eventnest.com',     'scrypt$16384$8$1$IVs9Fkl9+HSlBaDCXL7flw==$Q6+guXxTRS87WFRoKOKgTlAASLPlq+NCMaie07V+aTgzKyZfplkWH6iJfSc7Cf9BZpkx9dHeD4pzwdQScFDmAw==', 'System Administrator', 'Admin'),
 ('student@eventnest.com',   'scrypt$16384$8$1$VmLqLxttU2kbfgAQwCG6ig==$kKznOEx6hh//mBp7+aO/5rssN4V1Ne5xhaYbSnn9YWbgvf375tQwctFChZbi4+W0fQ8bgD8it79G1m0wlpQtHw==', 'Sample Student', 'User'),
 ('organizer@eventnest.com', 'scrypt$16384$8$1$VmLqLxttU2kbfgAQwCG6ig==$kKznOEx6hh//mBp7+aO/5rssN4V1Ne5xhaYbSnn9YWbgvf375tQwctFChZbi4+W0fQ8bgD8it79G1m0wlpQtHw==', 'Sample Organizer', 'User'),
 ('maria.santos@eventnest.com',   'scrypt$16384$8$1$VmLqLxttU2kbfgAQwCG6ig==$kKznOEx6hh//mBp7+aO/5rssN4V1Ne5xhaYbSnn9YWbgvf375tQwctFChZbi4+W0fQ8bgD8it79G1m0wlpQtHw==', 'Maria Santos', 'User'),
 ('juan.delacruz@eventnest.com',  'scrypt$16384$8$1$VmLqLxttU2kbfgAQwCG6ig==$kKznOEx6hh//mBp7+aO/5rssN4V1Ne5xhaYbSnn9YWbgvf375tQwctFChZbi4+W0fQ8bgD8it79G1m0wlpQtHw==', 'Juan Dela Cruz', 'User'),
 ('angela.reyes@eventnest.com',   'scrypt$16384$8$1$VmLqLxttU2kbfgAQwCG6ig==$kKznOEx6hh//mBp7+aO/5rssN4V1Ne5xhaYbSnn9YWbgvf375tQwctFChZbi4+W0fQ8bgD8it79G1m0wlpQtHw==', 'Angela Reyes', 'User'),
 ('carlo.mendoza@eventnest.com',  'scrypt$16384$8$1$VmLqLxttU2kbfgAQwCG6ig==$kKznOEx6hh//mBp7+aO/5rssN4V1Ne5xhaYbSnn9YWbgvf375tQwctFChZbi4+W0fQ8bgD8it79G1m0wlpQtHw==', 'Carlo Mendoza', 'User'),
 ('sofia.garcia@eventnest.com',   'scrypt$16384$8$1$VmLqLxttU2kbfgAQwCG6ig==$kKznOEx6hh//mBp7+aO/5rssN4V1Ne5xhaYbSnn9YWbgvf375tQwctFChZbi4+W0fQ8bgD8it79G1m0wlpQtHw==', 'Sofia Garcia', 'User'),
 ('miguel.torres@eventnest.com',  'scrypt$16384$8$1$VmLqLxttU2kbfgAQwCG6ig==$kKznOEx6hh//mBp7+aO/5rssN4V1Ne5xhaYbSnn9YWbgvf375tQwctFChZbi4+W0fQ8bgD8it79G1m0wlpQtHw==', 'Miguel Torres', 'User'),
 ('bea.villanueva@eventnest.com', 'scrypt$16384$8$1$VmLqLxttU2kbfgAQwCG6ig==$kKznOEx6hh//mBp7+aO/5rssN4V1Ne5xhaYbSnn9YWbgvf375tQwctFChZbi4+W0fQ8bgD8it79G1m0wlpQtHw==', 'Bea Villanueva', 'User');

-- NOTE: location and capacity are placeholder estimates. Edit them if you know the real values.
INSERT INTO venues (name, location, capacity) VALUES
 ('Sauras Hall Conference Rooms',                          'Main Campus',    60),
 ('College Lobby',                                         'Main Campus',   100),
 ('College Garden',                                        'Main Campus',   150),
 ('Multi-Purpose Covered Court 1 (MPCC 1)',                'Main Campus',  1000),
 ('Multi-Purpose Covered Court 2 (MPCC 2)',                'Main Campus',  1000),
 ('Audio-Visual Room (AVR)',                               'Main Campus',   120),
 ('Carlos Dominguez Conference Hall',                      'Main Campus',   200),
 ('FEC Conference Room',                                   'Main Campus',    40),
 ('Classrooms',                                            'Main Campus',    45),
 ('Designated Graduate School Rooms',                      'Main Campus',    40),
 ('Jesuit Residence Room 1',                               'Main Campus',    30),
 ('Jesuit Residence Room 2',                               'Main Campus',    30),
 ('LRC Garden',                                            'Main Campus',   150),
 ('Back Field',                                            'Main Campus',  2000),
 ('Sleeping Quarters',                                     'Main Campus',    50),
 ('Catwalks and Covered Walkways',                         'Main Campus',   300),
 ('Campion Lecture Hall',                                  'Main Campus',   250),
 ('Brebeuf Gym',                                           'Main Campus',  1500),
 ('Tee King Lecture Hall',                                 'Main Campus',   200),
 ('Lantaka Campus Function Hall A (formerly Capiz Hall)',  'Lantaka Campus', 200),
 ('Lantaka Campus Function Hall B (formerly Abreeza Hall)','Lantaka Campus', 200),
 ('Lantaka Campus Function Hall C (Dining Hall)',          'Lantaka Campus', 300),
 ('Audio-Visual Center Viewing Room (Room 302-A)',         'Main Campus',    50),
 ('ASRC Screening Room (Room 208)',                        'Main Campus',    60),
 ('LRC Conference Room (Rooms 102 A&B)',                   'Main Campus',    50),
 ('AVC Preview Corner (Room 301-B)',                       'Main Campus',    20);

-- Event happening right now (so the "Current" view has data).
INSERT INTO events (requested_by, reviewed_by, venue_id, title, description, category, hosting_organization, target_audience,
                    start_datetime, end_datetime, status, reviewed_at) VALUES
 (3,1,17,'Research Colloquium','Presentation of ongoing student research.','Academic','Research Office','Faculty and students',
   (NOW() AT TIME ZONE 'Asia/Manila') - interval '1 hour',
   (NOW() AT TIME ZONE 'Asia/Manila') + interval '2 hours','Approved', NOW() AT TIME ZONE 'Asia/Manila');

-- All other events. d = day offset from today (Manila); s/e = start/end time.
-- Approved events never overlap at the same venue (the exclusion constraint would reject them).
INSERT INTO events (requested_by, reviewed_by, venue_id, title, description, category, hosting_organization, target_audience,
                    start_datetime, end_datetime, status, reviewed_at, rejection_reason)
SELECT v.req, v.rev, v.venue, v.title, v.descr, v.cat, v.host, v.aud,
       date_trunc('day', NOW() AT TIME ZONE 'Asia/Manila') + v.d * interval '1 day' + v.s::interval,
       date_trunc('day', NOW() AT TIME ZONE 'Asia/Manila') + v.d * interval '1 day' + v.e::interval,
       v.status,
       CASE WHEN v.status = 'Pending' THEN NULL ELSE NOW() AT TIME ZONE 'Asia/Manila' END,
       v.reason
FROM (VALUES
 -- ===== Completed (past) =====
 (3, 1, 18, 'Intramurals Opening Ceremony', 'Parade of teams and opening program.', 'Sports', 'Student Affairs Office', 'All students', -45, '08:00', '12:00', 'Completed', NULL),
 (4, 1, 5,  'Freshmen Orientation', 'Orientation program for incoming first-year students.', 'Institutional', 'Student Affairs Office', 'First-year students', -40, '08:00', '12:00', 'Completed', NULL),
 (5, 1, 11, 'Recollection Day', 'Day of prayer and reflection for student leaders.', 'Religious', 'Campus Ministry', 'Student leaders', -35, '08:00', '16:00', 'Completed', NULL),
 (3, 1, 4,  'College Foundation Day', 'Annual celebration of the college.', 'Institutional', 'CSITE', 'Faculty and students', -30, '09:00', '17:00', 'Completed', NULL),
 (6, 1, 2,  'Blood Donation Drive', 'Community blood donation.', 'Community', 'Red Cross Youth', 'All', -28, '08:00', '12:00', 'Completed', NULL),
 (2, 1, 7,  'Leadership Seminar', 'Seminar for student leaders.', 'Academic', 'Student Council', 'Student leaders', -21, '13:00', '16:00', 'Completed', NULL),
 (7, 1, 10, 'Graduate School Research Forum', 'Graduate students present their research.', 'Academic', 'Graduate School', 'Graduate students', -18, '14:00', '17:00', 'Completed', NULL),
 (8, 1, 25, 'Programming Contest', 'Inter-class programming competition.', 'Academic', 'Computer Science Society', 'CS students', -14, '09:00', '15:00', 'Completed', NULL),
 (9, 1, 23, 'Documentary Night', 'Screening and discussion of a documentary.', 'Socio-cultural', 'Film Club', 'Students', -10, '18:00', '21:00', 'Completed', NULL),
 (10, 1, 14, 'Campus Clean-up Drive', 'Volunteer clean-up of the campus grounds.', 'Community', 'Environment Club', 'Volunteers', -7, '07:00', '10:00', 'Completed', NULL),
 -- ===== Approved (upcoming) =====
 (3, 1, 4,  'Career Fair', 'Partner companies recruit graduating students.', 'Career', 'Career Services', 'Graduating students', 2, '09:00', '16:00', 'Approved', NULL),
 (4, 1, 18, 'Mass of the Holy Spirit', 'Opening mass for the semester.', 'Religious', 'Campus Ministry', 'All students', 3, '08:00', '10:00', 'Approved', NULL),
 (2, 1, 7,  'Faculty Meeting', 'Monthly faculty meeting.', 'Institutional', 'Dean''s Office', 'Faculty', 4, '08:00', '12:00', 'Approved', NULL),
 (5, 1, 7,  'Leadership Training', 'Training workshop for incoming officers.', 'Academic', 'Student Council', 'Student leaders', 4, '13:00', '17:00', 'Approved', NULL),
 (8, 1, 25, 'Coding Bootcamp', 'Hands-on programming workshop.', 'Academic', 'Computer Science Society', 'CS students', 4, '09:00', '17:00', 'Approved', NULL),
 (2, 1, 5,  'Cultural Night', 'Showcase of campus cultural groups.', 'Socio-cultural', 'Cultural Committee', 'All students', 5, '18:00', '21:00', 'Approved', NULL),
 (6, 1, 18, 'Intramurals Basketball Finals', 'Championship games.', 'Sports', 'Student Affairs Office', 'All students', 6, '13:00', '18:00', 'Approved', NULL),
 (9, 1, 24, 'Short Film Festival', 'Screening of student-made short films.', 'Socio-cultural', 'Film Club', 'Students', 7, '14:00', '18:00', 'Approved', NULL),
 (7, 1, 4,  'Science Fair', 'Student science projects on display.', 'Academic', 'Science Society', 'All students', 8, '09:00', '16:00', 'Approved', NULL),
 (3, 1, 18, 'Organization Recognition Assembly', 'Recognition of accredited student organizations.', 'Institutional', 'Student Affairs Office', 'Organization officers', 9, '09:00', '12:00', 'Approved', NULL),
 (4, 1, 20, 'Faculty Appreciation Day', 'Program honoring faculty members.', 'Institutional', 'Student Council', 'Faculty and students', 10, '08:00', '12:00', 'Approved', NULL),
 (10, 1, 2, 'Photography Exhibit', 'Exhibit of student photography.', 'Socio-cultural', 'Photography Club', 'All', 11, '09:00', '17:00', 'Approved', NULL),
 (5, 1, 22, 'Alumni Homecoming', 'Dinner and program for alumni.', 'Institutional', 'Alumni Office', 'Alumni', 12, '17:00', '22:00', 'Approved', NULL),
 (6, 1, 19, 'Debate Tournament', 'Inter-school debate competition.', 'Academic', 'Debate Society', 'Students', 13, '09:00', '17:00', 'Approved', NULL),
 (7, 1, 10, 'Thesis Defense Orientation', 'Briefing on thesis defense procedures.', 'Academic', 'Graduate School', 'Graduate students', 14, '13:00', '16:00', 'Approved', NULL),
 (9, 1, 13, 'Sunset Acoustic Night', 'Open-air acoustic performances.', 'Socio-cultural', 'Music Society', 'All students', 15, '17:00', '20:00', 'Approved', NULL),
 (10, 1, 14, 'Football Friendly Match', 'Friendly match between colleges.', 'Sports', 'Varsity Football Team', 'All', 16, '15:00', '18:00', 'Approved', NULL),
 -- ===== Pending (waiting for admin review) =====
 (6, NULL, 2,  'Blood Donation Drive (Second Round)', 'Follow-up community blood donation.', 'Community', 'Red Cross Youth', 'All', 6, '08:00', '12:00', 'Pending', NULL),
 (3, NULL, 3,  'Board Game Night', 'Casual board games and snacks.', 'Socio-cultural', 'Gaming Club', 'Students', 8, '18:00', '21:00', 'Pending', NULL),
 (4, NULL, 6,  'Mental Health Awareness Talk', 'Talk by guidance counselors.', 'Community', 'Guidance Office', 'All students', 9, '14:00', '16:00', 'Pending', NULL),
 (7, NULL, 5,  'Dance Workshop', 'Introductory dance workshop.', 'Socio-cultural', 'Dance Troupe', 'Students', 10, '15:00', '18:00', 'Pending', NULL),
 (8, NULL, 9,  'Math Quiz Bee', 'Quiz competition for all year levels.', 'Academic', 'Math Society', 'Students', 11, '13:00', '16:00', 'Pending', NULL),
 (2, NULL, 8,  'Entrepreneurship Seminar', 'Talk by local business owners.', 'Career', 'Business Club', 'Students', 13, '09:00', '12:00', 'Pending', NULL),
 (9, NULL, 25, 'Hackathon', '12-hour coding competition.', 'Academic', 'Computer Science Society', 'CS students', 18, '08:00', '20:00', 'Pending', NULL),
 (10, NULL, 14,'Tree Planting Activity', 'Planting of seedlings around the campus.', 'Community', 'Environment Club', 'Volunteers', 20, '07:00', '11:00', 'Pending', NULL),
 (5, NULL, 4,  'Organizations Fair', 'Booths from all student organizations.', 'Institutional', 'Student Affairs Office', 'All students', 21, '09:00', '16:00', 'Pending', NULL),
 -- ===== Rejected =====
 (2, 1, 4,  'Movie Marathon', 'Film screening.', 'Socio-cultural', 'Film Club', 'Students', 2, '14:00', '18:00', 'Rejected', 'Venue is reserved for the Career Fair.'),
 (4, 1, 5,  'Rock Concert', 'Live bands.', 'Socio-cultural', 'Music Society', 'All students', 5, '17:00', '22:00', 'Rejected', 'Venue is reserved for Cultural Night.'),
 (6, 1, 15, 'Overnight Camp', 'Overnight camping activity.', 'Social', 'Outdoor Club', 'Members', 9, '18:00', '23:00', 'Rejected', 'Sleeping Quarters are not available for student-organized overnight events.'),
 (8, 1, 3,  'Birthday Celebration', 'Personal celebration.', 'Social', 'N/A', 'Friends', 12, '17:00', '21:00', 'Rejected', 'Personal events cannot be booked through EventNest.'),
 (7, 1, 18, 'Fundraising Bazaar', 'Sale of food and merchandise.', 'Community', 'Business Club', 'All', 12, '09:00', '15:00', 'Rejected', 'Incomplete requirements. Please resubmit with the approval letter.')
) AS v(req, rev, venue, title, descr, cat, host, aud, d, s, e, status, reason);

-- Notifications are generated from the events above:
--   admin is told about Pending requests; requesters are told about decisions.
INSERT INTO notifications (user_id, event_id, message, is_read)
SELECT 1, event_id, 'New event request: "' || title || '" is waiting for review.', FALSE
  FROM events WHERE status = 'Pending'
UNION ALL
SELECT requested_by, event_id, 'Your event "' || title || '" was approved.', (event_id % 2 = 0)
  FROM events WHERE status IN ('Approved', 'Completed')
UNION ALL
SELECT requested_by, event_id, 'Your event "' || title || '" was rejected: ' || rejection_reason, FALSE
  FROM events WHERE status = 'Rejected';
