const { Driver, storage } = require('../config/config');
const jwt = require('jsonwebtoken');

async function addDriver(driverData, file) {
    try {
        const newDriver = driverData ? driverData : {};

        if (file) {
            const photoName = `drivers/${Date.now()}_${file.originalname}`;
            const photoUrl = await uploadPhoto(file.buffer, photoName);
            newDriver.photo = photoUrl;
        }

        const driverRef = await Driver.push();
        const driverId = driverRef.key;

        await Driver.child(driverId).set({ id: driverId, ...newDriver });

        const token = generateTokenn(driverId);

        return { driver: { id: driverId, ...newDriver }, token };
    } catch (error) {
        throw error;
    }
}

async function getDrivers() {
    const driversSnapshot = await Driver.once('value');
    return Object.keys(driversSnapshot.val() || {}).map((id) => ({ id, ...driversSnapshot.val()[id] }));
}


async function updateDriver(id, updatedFields) {
  try {
      // Verifica si el conductor existe antes de intentar actualizarlo
      const existingDriver = await getDriverById(id);
      if (existingDriver) {
          // Actualiza solo los campos proporcionados en el objeto actualizado
          await Driver.child(id).update(updatedFields);
      } else {
          throw new Error('Driver not found');
      }
  } catch (error) {
      throw error;
  }
}








async function getDriverById(driverId) {
  const driverDoc = await Driver.child(driverId).once('value');

  if (!driverDoc.exists()) {
      throw new Error('Driver not found');
  }

  return { id: driverDoc.key, ...driverDoc.val() };
}









async function deleteDriver(id) {
    await Driver.child(id).remove();
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

function generateTokenn(driverId) {
    const secretKey = process.env.JWT_SECRET;
    const token = jwt.sign({ driverId }, secretKey, { expiresIn: '1h' });
    return token;
}

module.exports = {
    addDriver,
    getDrivers,
    updateDriver,
    deleteDriver,
    generateTokenn,
    uploadPhoto,
    getDriverById
};
