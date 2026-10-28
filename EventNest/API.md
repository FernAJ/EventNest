# EventNest API

All endpoints are under `/api`, return JSON, and need login except health/signup/login.
Login sets an HttpOnly cookie; you may also send `Authorization: Bearer <token>`.
Frontend pages call these endpoints with fetch().
Dates are campus time (Asia/Manila), format `YYYY-MM-DDTHH:MM`.
Errors: `{ "error": "message" }` with 400 / 401 / 403 / 404 / 409.

| Method | Path | Access | Notes |
|---|---|---|---|
| GET | /health | public | DB check |
| POST | /auth/signup | public | `{email, password(min 8), full_name?}` -> role User |
| POST | /auth/login | public | `{email, password}` -> `{user, token}` |
| POST | /auth/logout | any | clears cookie |
| GET | /auth/me | auth | current user |
| GET | /stats | auth | `{current, upcoming, archived, pending(admin)}` |
| GET | /venues | auth | list |
| POST | /venues | admin | `{name, location, capacity}` |
| GET | /events?view=current\|upcoming\|archive | auth | approved/completed events |
| GET | /events/mine | auth | my requests, all statuses |
| GET | /events/:id | auth | pending/rejected visible to owner + admin only |
| POST | /events | auth | `{title, venue_id, start_datetime, end_datetime, description?, category?, hosting_organization?, target_audience?}`. User -> Pending, Admin -> Approved |
| PUT | /events/:id | admin, or owner while Pending | edit |
| DELETE | /events/:id | admin, or owner while Pending | |
| GET | /admin/events?status=Pending | admin | review queue |
| PATCH | /events/:id/approve | admin | 409 if venue already booked at that time |
| PATCH | /events/:id/reject | admin | `{reason?}` |
| PATCH | /events/:id/finish | admin | Approved -> Completed (goes to Archive) |
| GET | /notifications | auth | `{unread, items}` |
| PATCH | /notifications/:id/read, /notifications/read-all | auth | |
