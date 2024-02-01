const express = require('express');
const router = express.Router();
const { Flete, User } = require('../config/config');

router.post('/fletes', async (req, res) => {
    try {
        const newFlete = req.body;

        const userDoc = await User.doc(newFlete.userId).get();
        if (!userDoc.exists) {
            res.status(404).json({ error: 'User not found' });
            return;
        }

        const fleteRef = await Flete.add(newFlete);
        const fleteId = fleteRef.id;

        await Flete.doc(fleteId).update({ id: fleteId });

        res.send({ msg: 'Flete added successfully', flete: { id: fleteId, ...newFlete } });
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

router.get('/fletes', async (req, res) => {
    try {
        const fletesSnapshot = await Flete.get();
        const fletes = fletesSnapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
        res.send({ fletes });
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Internal server error' });
    }
});


router.get('/fletes/:id', async (req, res) => {
    try {
        const { id } = req.params;
        const fleteDoc = await Flete.doc(id).get();
        if (!fleteDoc.exists) {
            res.status(404).json({ error: 'Flete not found' });
            return;
        }
        const flete = { id: fleteDoc.id, ...fleteDoc.data() };
        res.send({ flete });
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

router.put('/fletes/:id', async (req, res) => {
    try {
        const { id } = req.params;
        const { body } = req;

        let updatedFlete;
        try {
            updatedFlete = JSON.parse(body);
        } catch (error) {
            throw new Error('Invalid JSON data in the request body');
        }

        await Flete.doc(id).update(updatedFlete);

        res.send({ msg: 'Flete updated successfully', flete: { id, ...updatedFlete } });
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Internal server error' });
    }
});




router.delete('/fletes/:id', async (req, res) => {
    try {
        const { id } = req.params;

        await Flete.doc(id).delete();

        res.send({ msg: 'Flete deleted successfully' });
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
module.exports = router;
