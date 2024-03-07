const express = require('express');
const multer = require('multer');
const router = express.Router();
const driverService = require('../services/driverService');
const { addDriver, generateTokenn } = require('../services/driverService');
const authMiddleware = require('../middleware/authMiddleware');

const upload = multer({ storage: multer.memoryStorage() });

router.post('/drivers', upload.single('photo'), async (req, res) => {
    try {
        const { body, file } = req;

        const driverData = typeof body === 'string' ? JSON.parse(body) : body;

        const driver = await addDriver(driverData, file);
        const token = generateTokenn(driver.id);

        res.send({ driver: { ...driver, token } });
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

router.get('/drivers/:id', async (req, res) => {
    const driverId = req.params.id;
    try {
        const driver = await driverService.getDriverById(driverId);
        res.json(driver);
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

router.get('/drivers', async (req, res) => {
    try {
        const drivers = await driverService.getDrivers();
        res.send({ drivers });
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

router.put('/drivers/:id', upload.single('photo'), async (req, res) => {
    try {
        const { id } = req.params;
        const { body, file } = req;

        let updatedDriver = body; 

        if (file) {
            const photoName = `drivers/${Date.now()}_${file.originalname}`;
            const photoUrl = await driverService.uploadPhoto(file.buffer, photoName);
            updatedDriver.photo = photoUrl;
        }

        await driverService.updateDriver(id, updatedDriver);

        res.send({ msg: 'Driver updated successfully', driver: { id, ...updatedDriver } });
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Internal server error' });
    }
});





router.delete('/drivers/:id', async (req, res) => {
    try {
        const { id } = req.params;
        await driverService.deleteDriver(id);
        res.send({ msg: 'Driver deleted successfully' });
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

module.exports = router;
