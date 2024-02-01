const jwt = require('jsonwebtoken');

function authMiddleware(req, res, next) {
  const { authorization } = req.headers;
  const token = authorization && authorization.split(' ')[1];

  if (!token && req.method !== 'PUT') {
    if (req.method === 'GET' || req.method === 'DELETE') {
      req.user = null;
      return next();
    }

    return res.status(401).json({ error: 'Unauthorized: Missing token' });
  }

  try {
    if (token) {
      const decoded = jwt.verify(token, process.env.JWT_SECRET);
      req.user = decoded.userId;
    }
    next();
  } catch (error) {
    res.status(401).json({ error: 'Unauthorized: Invalid token' });
  }
}

module.exports = authMiddleware;
