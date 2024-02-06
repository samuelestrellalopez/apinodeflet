  const { User, storage } = require('../config/config');
  const jwt = require('jsonwebtoken');

  function generateToken(userId) {
    const secretKey = process.env.JWT_SECRET;

    const token = jwt.sign({ userId }, secretKey, { expiresIn: '1h' });
    return token;
  }


  async function uploadPhoto(buffer, photoName) {
    try {
      const photoFile = storage.ref().child(photoName);
      await photoFile.put(buffer);
      const photoUrl = await photoFile.getDownloadURL();
      return photoUrl;
    } catch (error) {
      throw error;
    }
  }

async function addUser(userData, file) {
  try {
    if (!userData) {
      throw new Error('Se requieren datos de usuario para agregar un nuevo usuario');
    }

    const newUser = { ...userData }; // Clonar los datos de usuario para evitar modificaciones no deseadas

    if (file) {
      const photoName = `users/${Date.now()}_${file.originalname}`;
      newUser.photo = await uploadPhoto(file.buffer, photoName);
    }

    // Verificar si el usuario ya tiene un ID proporcionado
    const userId = newUser.id || (await User.push()).key;

    // Agregar el ID del usuario a los datos del nuevo usuario
    newUser.id = userId;

    await User.child(userId).set(newUser);

    const token = generateToken(userId);

    return { user: newUser, token };
  } catch (error) {
    throw error;
  }
}





  async function getUsers() {
    try {
      const usersSnapshot = await User.orderByChild('name').once('value');
      const users = [];

      usersSnapshot.forEach((userSnapshot) => {
        const user = { id: userSnapshot.key, ...userSnapshot.val() };
        users.push(user);
      });

      return users;
    } catch (error) {
      throw error;
    }
  }

  async function getUserById(userId) {
    try {
      const userSnapshot = await User.child(userId).once('value');  

      if (!userSnapshot.exists()) {
        throw new Error('User not found');
      }

      const user = { id: userSnapshot.key, ...userSnapshot.val() };
      return user;
    } catch (error) {
      throw error;
    }
  }



  async function updateUser(userId, updatedUserData) {
    try {
      const userSnapshot = await User.child(userId).once('value');

      if (!userSnapshot.exists()) {
        throw new Error('User not found');
      }

      const currentUser = userSnapshot.val();

      const updatedUser = { ...currentUser, ...updatedUserData };

      await User.child(userId).update(updatedUser);

      return { message: 'User updated successfully', user: updatedUser };
    } catch (error) {
      return { message: 'User not updated', error: error.message };
    }
  }



  async function deleteUser(userId) {
    try {
      const userSnapshot = await User.child(userId).once('value');  

      if (!userSnapshot.exists()) {
        throw new Error('User not found');
      }

      await User.child(userId).remove();  

      return;
    } catch (error) {
      throw error;
    }
  }



  module.exports = {
    getUserById,
    addUser,
    getUsers,
    updateUser,
    deleteUser,
    generateToken
  };
