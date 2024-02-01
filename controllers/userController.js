const express = require('express');
const multer = require('multer');
const router = express.Router();
const userService = require('../services/usersService');
const authMiddleware = require('../middleware/authMiddleware');

const {  generateToken } = require('../services/usersService');

const upload = multer({ storage: multer.memoryStorage() });

router.post('/users', upload.single('photo'), async (req, res) => {
  try {
    const { body, file } = req;

    const userData = typeof body === 'string' ? JSON.parse(body) : body;

    const user = await userService.addUser(userData, file);
    

    const token = generateToken(user.id);

    res.send({ user: { ...user, token } });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Internal server error' });
  }
});



//holaaaa


router.get('/users', async (req, res) => {
  try {
    const users = await userService.getUsers();
    res.send({ users });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Internal server error' });
  }
});


router.get('/users/:id', authMiddleware, async (req, res) => {
    const userId = req.params.id;
    try {
      const user = await userService.getUserById(userId);
      res.json(user);
    } catch (error) {
      console.error(error);
      res.status(500).json({ error: 'Internal Server Error' });
    }
  });
  
 router.put('/users/:id', authMiddleware, async (req, res) => {
  const userId = req.params.id;
  const updatedUserData = req.body;
  try {
    const updatedUser = await userService.updateUser(userId, updatedUserData);
    res.json(updatedUser);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

  router.delete('/users/:id', authMiddleware, async (req, res) => {
    const userId = req.params.id;
    try {
      await userService.deleteUser(userId);
      res.json({ message: 'User deleted successfully' });
    } catch (error) {
      console.error(error);
      res.status(500).json({ error: 'Internal Server Error' });
    }
  });


module.exports = router;
