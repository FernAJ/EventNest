const express = require("express");
const db = require("./db");
const { hashPassword, verifyPassword, signToken } = require("./security");
const { SECRET, COOKIE, TTL, requireAuth, requireAdmin } = require("./auth");

const router = express.Router();
const NOW = "(NOW() AT TIME ZONE 'Asia/Manila')";

// ---------- helpers ----------
const EVENT_SQL = `
  SELECT e.*, v.name AS venue_name, v.location AS venue_location,
         u.full_name AS requested_by_name, u.email AS requested_by_email
  FROM events e
  JOIN venues v ON v.venue_id = e.venue_id
  JOIN users  u ON u.user_id  = e.requested_by`;

const VIEWS = {
  current:  `e.status='Approved' AND e.start_datetime <= ${NOW} AND e.end_datetime >= ${NOW}`,
  upcoming: `e.status='Approved' AND e.start_datetime > ${NOW}`,
  archive:  `(e.status='Completed' OR (e.status='Approved' AND e.end_datetime < ${NOW}))`,
};
const isDate = (s) => typeof s === "string" && /^\d{4}-\d{2}-\d{2}([T ]\d{2}:\d{2}(:\d{2})?)?$/.test(s) && !isNaN(Date.parse(s));
const bad = (res, msg) => res.status(400).json({ error: msg });
const failedLogins = new Map(); // ip -> {n, t}
const WINDOW = 15 * 60 * 1000;

async function notify(userId, eventId, message) {
  await db.query("INSERT INTO notifications(user_id,event_id,message) VALUES ($1,$2,$3)", [userId, eventId, message]);
}
function setCookie(res, token) {
  const secure = process.env.NODE_ENV === "production" ? "; Secure" : "";
  res.setHeader("Set-Cookie", `${COOKIE}=${encodeURIComponent(token)}; HttpOnly; Path=/; SameSite=Lax; Max-Age=${TTL}${secure}`);
}
const publicUser = (u) => ({ user_id: u.user_id, email: u.email, full_name: u.full_name, role: u.role });
const issue = (u) => signToken({ user_id: u.user_id, role: u.role, email: u.email }, SECRET, TTL);
const loadEvent = async (id) => (await db.query("SELECT * FROM events WHERE event_id=$1", [id])).rows[0];

// ---------- health ----------
router.get("/health", async (req, res) => {
  await db.query("SELECT 1");
  res.json({ ok: true, time: new Date().toISOString() });
});

// ---------- auth ----------
router.post("/auth/signup", async (req, res) => {
  const { email, password } = req.body || {};
  const full_name = (req.body?.full_name || String(email || "").split("@")[0]).trim();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email || "")) return bad(res, "Enter a valid email address.");
  if (typeof password !== "string" || password.length < 8) return bad(res, "Password must be at least 8 characters.");
  const r = await db.query(
    `INSERT INTO users(email,password_hash,full_name,role) VALUES (lower($1),$2,$3,'User')
     ON CONFLICT (email) DO NOTHING RETURNING *`, [email.trim(), hashPassword(password), full_name]);
  if (!r.rowCount) return res.status(409).json({ error: "That email is already registered." });
  const token = issue(r.rows[0]);
  setCookie(res, token);
  res.status(201).json({ user: publicUser(r.rows[0]), token });
});

router.post("/auth/login", async (req, res) => {
  const ip = req.ip, rec = failedLogins.get(ip);
  if (rec && rec.n >= 10 && Date.now() - rec.t < WINDOW)
    return res.status(429).json({ error: "Too many failed attempts. Try again in 15 minutes." });
  const { email, password } = req.body || {};
  const u = (await db.query("SELECT * FROM users WHERE email = lower($1)", [String(email || "").trim()])).rows[0];
  if (!u || !verifyPassword(String(password || ""), u.password_hash)) {
    failedLogins.set(ip, { n: (rec && Date.now() - rec.t < WINDOW ? rec.n : 0) + 1, t: Date.now() });
    return res.status(401).json({ error: "Invalid email or password." });
  }
  failedLogins.delete(ip);
  const token = issue(u);
  setCookie(res, token);
  res.json({ user: publicUser(u), token });
});

router.post("/auth/logout", (req, res) => {
  res.setHeader("Set-Cookie", `${COOKIE}=; HttpOnly; Path=/; Max-Age=0`);
  res.json({ ok: true });
});
router.get("/auth/me", requireAuth, async (req, res) => {
  const r = await db.query("SELECT * FROM users WHERE user_id=$1", [req.user.user_id]);
  if (!r.rowCount) return res.status(401).json({ error: "Account no longer exists." });
  res.json({ user: publicUser(r.rows[0]) });
});

// ---------- venues ----------
router.get("/venues", requireAuth, async (req, res) => {
  res.json((await db.query("SELECT * FROM venues ORDER BY name")).rows);
});
router.post("/venues", requireAuth, requireAdmin, async (req, res) => {
  const { name, location, capacity } = req.body || {};
  if (!name) return bad(res, "Venue name is required.");
  const r = await db.query("INSERT INTO venues(name,location,capacity) VALUES ($1,$2,$3) RETURNING *",
    [name.trim(), location || null, Number.isInteger(capacity) ? capacity : null]);
  res.status(201).json(r.rows[0]);
});

// ---------- stats ----------
router.get("/stats", requireAuth, async (req, res) => {
  const r = await db.query(`
    SELECT COUNT(*) FILTER (WHERE ${VIEWS.current})  AS current,
           COUNT(*) FILTER (WHERE ${VIEWS.upcoming}) AS upcoming,
           COUNT(*) FILTER (WHERE ${VIEWS.archive})  AS archived,
           COUNT(*) FILTER (WHERE e.status='Pending') AS pending
    FROM events e`);
  const s = Object.fromEntries(Object.entries(r.rows[0]).map(([k, v]) => [k, Number(v)]));
  if (req.user.role !== "Admin") delete s.pending;
  res.json(s);
});

// ---------- events ----------
// ?view=current|upcoming|archive  (default: all approved + completed)
router.get("/events", requireAuth, async (req, res) => {
  const where = VIEWS[req.query.view] || `e.status IN ('Approved','Completed')`;
  const dir = req.query.view === "archive" ? "DESC" : "ASC";
  res.json((await db.query(`${EVENT_SQL} WHERE ${where} ORDER BY e.start_datetime ${dir}`)).rows);
});
router.get("/events/mine", requireAuth, async (req, res) => {
  res.json((await db.query(`${EVENT_SQL} WHERE e.requested_by=$1 ORDER BY e.created_at DESC`, [req.user.user_id])).rows);
});
router.get("/admin/events", requireAuth, requireAdmin, async (req, res) => {
  const params = [];
  let where = "";
  if (["Pending", "Approved", "Rejected", "Completed"].includes(req.query.status)) { params.push(req.query.status); where = "WHERE e.status=$1"; }
  res.json((await db.query(`${EVENT_SQL} ${where} ORDER BY e.start_datetime`, params)).rows);
});
router.get("/events/:id", requireAuth, async (req, res) => {
  const e = (await db.query(`${EVENT_SQL} WHERE e.event_id=$1`, [req.params.id])).rows[0];
  const hidden = e && ["Pending", "Rejected"].includes(e.status) && req.user.role !== "Admin" && e.requested_by !== req.user.user_id;
  if (!e || hidden) return res.status(404).json({ error: "Event not found." });
  res.json(e);
});

// Users submit a request (Pending); admins create directly as Approved.
router.post("/events", requireAuth, async (req, res) => {
  const b = req.body || {};
  if (!b.title?.trim()) return bad(res, "Title is required.");
  if (!Number.isInteger(+b.venue_id)) return bad(res, "Choose a venue.");
  if (!isDate(b.start_datetime) || !isDate(b.end_datetime)) return bad(res, "Valid start and end date/time are required.");
  if (Date.parse(b.end_datetime) <= Date.parse(b.start_datetime)) return bad(res, "End must be after start.");
  const admin = req.user.role === "Admin";
  const r = await db.query(
    `INSERT INTO events(requested_by,reviewed_by,reviewed_at,venue_id,title,description,category,
        hosting_organization,target_audience,start_datetime,end_datetime,status)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12) RETURNING *`,
    [req.user.user_id, admin ? req.user.user_id : null, admin ? new Date() : null, +b.venue_id, b.title.trim(),
     b.description || null, b.category || "General", b.hosting_organization || "N/A", b.target_audience || "All",
     b.start_datetime, b.end_datetime, admin ? "Approved" : "Pending"]);
  const e = r.rows[0];
  if (!admin) {
    for (const a of (await db.query("SELECT user_id FROM users WHERE role='Admin'")).rows)
      await notify(a.user_id, e.event_id, `New event request: "${e.title}" is waiting for review.`);
  }
  res.status(201).json(e);
});

router.patch("/events/:id/approve", requireAuth, requireAdmin, async (req, res) => {
  const e = await loadEvent(req.params.id);
  if (!e) return res.status(404).json({ error: "Event not found." });
  if (e.status !== "Pending") return res.status(409).json({ error: `Only Pending events can be approved (this one is ${e.status}).` });
  // A venue/time clash is rejected by the DB exclusion constraint -> 409 via the error handler.
  const r = await db.query("UPDATE events SET status='Approved', reviewed_by=$2, reviewed_at=NOW(), rejection_reason=NULL WHERE event_id=$1 RETURNING *",
    [e.event_id, req.user.user_id]);
  await notify(e.requested_by, e.event_id, `Your event "${e.title}" was approved.`);
  res.json(r.rows[0]);
});
router.patch("/events/:id/reject", requireAuth, requireAdmin, async (req, res) => {
  const e = await loadEvent(req.params.id);
  if (!e) return res.status(404).json({ error: "Event not found." });
  if (e.status !== "Pending") return res.status(409).json({ error: `Only Pending events can be rejected (this one is ${e.status}).` });
  const reason = (req.body?.reason || "").trim() || null;
  const r = await db.query("UPDATE events SET status='Rejected', reviewed_by=$2, reviewed_at=NOW(), rejection_reason=$3 WHERE event_id=$1 RETURNING *",
    [e.event_id, req.user.user_id, reason]);
  await notify(e.requested_by, e.event_id, `Your event "${e.title}" was rejected${reason ? ": " + reason : "."}`);
  res.json(r.rows[0]);
});
router.patch("/events/:id/finish", requireAuth, requireAdmin, async (req, res) => {
  const e = await loadEvent(req.params.id);
  if (!e) return res.status(404).json({ error: "Event not found." });
  if (e.status !== "Approved") return res.status(409).json({ error: "Only Approved events can be finished." });
  res.json((await db.query("UPDATE events SET status='Completed' WHERE event_id=$1 RETURNING *", [e.event_id])).rows[0]);
});

// Edit: admin any event, owner only while Pending
router.put("/events/:id", requireAuth, async (req, res) => {
  const e = await loadEvent(req.params.id);
  if (!e) return res.status(404).json({ error: "Event not found." });
  const admin = req.user.role === "Admin";
  if (!admin && !(e.requested_by === req.user.user_id && e.status === "Pending"))
    return res.status(403).json({ error: "You can only edit your own pending requests." });
  const b = { ...e, ...req.body };
  if (!isDate(String(b.start_datetime)) || !isDate(String(b.end_datetime)) || Date.parse(b.end_datetime) <= Date.parse(b.start_datetime))
    return bad(res, "End must be after start.");
  const r = await db.query(
    `UPDATE events SET venue_id=$2,title=$3,description=$4,category=$5,hosting_organization=$6,target_audience=$7,
       start_datetime=$8,end_datetime=$9 WHERE event_id=$1 RETURNING *`,
    [e.event_id, +b.venue_id, String(b.title).trim(), b.description, b.category, b.hosting_organization, b.target_audience, b.start_datetime, b.end_datetime]);
  res.json(r.rows[0]);
});

router.delete("/events/:id", requireAuth, async (req, res) => {
  const e = await loadEvent(req.params.id);
  if (!e) return res.status(404).json({ error: "Event not found." });
  const admin = req.user.role === "Admin";
  if (!admin && !(e.requested_by === req.user.user_id && e.status === "Pending"))
    return res.status(403).json({ error: "You can only delete your own pending requests." });
  if (admin && e.requested_by !== req.user.user_id) await notify(e.requested_by, null, `Your event "${e.title}" was removed by an administrator.`);
  await db.query("DELETE FROM events WHERE event_id=$1", [e.event_id]); // notifications keep their rows (event_id -> NULL)
  res.json({ ok: true });
});

// ---------- notifications ----------
router.get("/notifications", requireAuth, async (req, res) => {
  const items = (await db.query("SELECT * FROM notifications WHERE user_id=$1 ORDER BY created_at DESC LIMIT 50", [req.user.user_id])).rows;
  res.json({ unread: items.filter((n) => !n.is_read).length, items });
});
router.patch("/notifications/read-all", requireAuth, async (req, res) => {
  await db.query("UPDATE notifications SET is_read=TRUE WHERE user_id=$1", [req.user.user_id]);
  res.json({ ok: true });
});
router.patch("/notifications/:id/read", requireAuth, async (req, res) => {
  const r = await db.query("UPDATE notifications SET is_read=TRUE WHERE notification_id=$1 AND user_id=$2 RETURNING *", [req.params.id, req.user.user_id]);
  if (!r.rowCount) return res.status(404).json({ error: "Notification not found." });
  res.json(r.rows[0]);
});

module.exports = router;
