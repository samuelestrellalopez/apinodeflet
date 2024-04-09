const express = require('express');
const router = express.Router();
const fleteService = require('../services/fleteService');
const { addFlete } = require('../services/fleteService');
const { generateToken } = require('../services/usersService');
router.use(express.json());

router.post('/fletes', async (req, res) => {
    try {
        const newFlete = req.body;

        const token = req.method === 'POST' ? generateToken(newFlete.userId) : null;

        const flete = await addFlete(newFlete);

        res.send({ msg: 'Flete added successfully', flete, token });
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Internal server error' });
    }
});


router.get('/fletes', async (req, res) => {
    try {
        const fletes = await fleteService.getFletes();
        res.send({ fletes });
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

router.get('/fletes/:id', async (req, res) => {
    try {
        const { id } = req.params;
        const flete = await fleteService.getFleteById(id);
        res.send({ flete });
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Internal server error' });
    }
});



router.put('/fletes/:id', async (req, res) => {
    try {
        const { id } = req.params;
        const updatedFlete = req.body; // Directamente accede al cuerpo ya parseado como un objeto JavaScript

        await fleteService.updateFlete(id, updatedFlete);

        res.send({ msg: 'Flete updated successfully', flete: { id, ...updatedFlete } });
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Internal server error' });
    }
});


router.delete('/fletes/:id', async (req, res) => {
    try {
        const { id } = req.params;
        await fleteService.deleteFlete(id);
        res.send({ msg: 'Flete deleted successfully' });
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

module.exports = router;

