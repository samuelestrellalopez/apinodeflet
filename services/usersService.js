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
    const newUser = userData ? userData : {};

    if (file) {
      const photoName = `users/${Date.now()}_${file.originalname}`;
      newUser.photo = await uploadPhoto(file.buffer, photoName);
    }

    const userRef = await User.push();
    const userId = userRef.key;

    await User.child(userId).set({ ...newUser, id: userId });

    const token = generateToken(userId);

    return { user: { id: userId, ...newUser }, token };
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

    // Obtén el usuario actual
    const currentUser = userSnapshot.val();

    // Actualiza los campos que se deben cambiar
    const updatedUser = { ...currentUser, ...updatedUserData };

    // Actualiza el usuario en la base de datos
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
