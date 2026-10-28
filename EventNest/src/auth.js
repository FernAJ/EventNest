require("./env");
const { verifyToken } = require("./security");
const SECRET = process.env.JWT_SECRET || "dev-only-secret-change-me";
const COOKIE = "en_token";
const TTL = 60 * 60 * 8; // 8 hours

function readToken(req) {
  const h = req.headers.authorization || "";
  if (h.startsWith("Bearer ")) return h.slice(7);
  const m = (req.headers.cookie || "").match(new RegExp("(?:^|;\\s*)" + COOKIE + "=([^;]+)"));
  return m ? decodeURIComponent(m[1]) : null;
}
function requireAuth(req, res, next) {
  const data = verifyToken(readToken(req), SECRET);
  if (!data) return res.status(401).json({ error: "Please log in." });
  req.user = { user_id: data.user_id, role: data.role, email: data.email };
  next();
}
function requireAdmin(req, res, next) {
  if (req.user.role !== "Admin") return res.status(403).json({ error: "Admin access required." });
  next();
}
module.exports = { SECRET, COOKIE, TTL, requireAuth, requireAdmin };
