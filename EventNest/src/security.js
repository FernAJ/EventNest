// Password hashing + signed tokens using only Node's built-in crypto.
const crypto = require("crypto");
const P = { N: 16384, r: 8, p: 1, keylen: 64 };

function hashPassword(password) {
  const salt = crypto.randomBytes(16);
  const h = crypto.scryptSync(password, salt, P.keylen, { N: P.N, r: P.r, p: P.p });
  return ["scrypt", P.N, P.r, P.p, salt.toString("base64"), h.toString("base64")].join("$");
}
function verifyPassword(password, stored) {
  try {
    const [scheme, N, r, p, s, h] = String(stored).split("$");
    if (scheme !== "scrypt") return false;
    const expected = Buffer.from(h, "base64");
    const actual = crypto.scryptSync(password, Buffer.from(s, "base64"), expected.length, { N: +N, r: +r, p: +p });
    return actual.length === expected.length && crypto.timingSafeEqual(actual, expected);
  } catch { return false; }
}
const b64 = (x) => Buffer.from(x).toString("base64url");
function signToken(payload, secret, ttlSeconds) {
  const body = b64(JSON.stringify({ ...payload, exp: Math.floor(Date.now() / 1000) + ttlSeconds }));
  return body + "." + crypto.createHmac("sha256", secret).update(body).digest("base64url");
}
function verifyToken(token, secret) {
  try {
    const [body, sig] = String(token).split(".");
    const exp = crypto.createHmac("sha256", secret).update(body).digest("base64url");
    const a = Buffer.from(sig), b = Buffer.from(exp);
    if (a.length !== b.length || !crypto.timingSafeEqual(a, b)) return null;
    const data = JSON.parse(Buffer.from(body, "base64url").toString());
    return data.exp > Date.now() / 1000 ? data : null;
  } catch { return null; }
}
module.exports = { hashPassword, verifyPassword, signToken, verifyToken };
