# EventNest – Event Schedule Tracker

Ateneo de Zamboanga University · College of Science, Information Technology, and Engineering
Web Systems and Technologies · 1st Semester 2026-2027 · Section WEBSYSTECH-B

## Group Members
- Kench Allaiken R. Kong
- Anthony Jhon L. Berano
- Abdullah C. Lukman
- Anthony Gabriel Vitug
- Fernando Jr Saile Ancheta

## Tools and Software
Node.js 18+ (tested on 22), Express 5, PostgreSQL 14+ (tested on 16), pg, pgAdmin 4, VS Code, HTML/CSS/JavaScript (frontend), Render (hosting).
Passwords are hashed with scrypt and sessions use signed tokens, both through Node's built-in `crypto` (no extra packages).

## Setup
1. Install Node.js and PostgreSQL. In pgAdmin 4, create an empty database named `eventnest`
   (right-click Databases > Create > Database).
2. Copy `.env.example` to `.env` and set your PostgreSQL password:
   `DATABASE_URL=postgresql://postgres:YOUR_PASSWORD@localhost:5432/eventnest`
3. Import the database, using EITHER:
   - pgAdmin: right-click `eventnest` > Query Tool > open `database/eventnest.sql` > Run (F5); OR
   - Terminal: `npm install` then `npm run db:import`
4. `npm install`
5. `npm start`, then open http://localhost:3000
   - The site opens the User dashboard; if you are not logged in it sends you to the login page (`Admin.html`).
   - Log in as Admin to see the admin dashboard (approve/reject requests, add, edit, finish, delete events). Regular users are sent to `User.html`.

The import script is re-runnable (it recreates the tables and sample data). Sample event dates are relative to the import time.

## Test Accounts
| Role | Email | Password |
|---|---|---|
| Admin | admin@eventnest.com | Admin@123 |
| User | student@eventnest.com | User@123 |
| User | organizer@eventnest.com | User@123 |

New sign-ups always get the User role. Users submit event requests (Pending); the Admin approves or rejects them.
Two approved events cannot overlap at the same venue (enforced by the database).

## Deploy on Render
Push the project to GitHub > Render > New > Blueprint > select the repo (`render.yaml` creates the web service and PostgreSQL).
Then import the data once: in the Render database page copy the External Database URL and run
`DATABASE_URL="<url>" PGSSL=true npm run db:import` locally (or paste `eventnest.sql` into pgAdmin connected to that database).

## Folder Structure
```
server.js          app entry
src/               routes, auth, db, security helpers
database/          eventnest.sql (exported schema + data)
scripts/           import-db.js
public/            frontend: Admin.html (login + admin dashboard), User.html (user dashboard), Style.css
API.md             endpoint reference
```
