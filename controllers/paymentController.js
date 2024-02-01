// controllers/paymentController.js
const express = require('express');
const router = express.Router();
const stripe = require('stripe')('sk_test_51OcJloAIqkgFr3utG0nNfFTrxnoiGKiU4XpCyqIfJlEXvJmkmEQnkf5JDELtZscKplHKwJyhMfQsyvvfQI2hPwE100mbj5IKj7');  // Importa la librería de Stripe
const csrf = require('csurf');

const { Flete, User } = require('../config/config');
const csrfProtection = csrf({ cookie: true });

router.get('/payments', async ( res) => {
    try {
        const paymentsSnapshot = await Flete.get();
        const payments = paymentsSnapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
        res.send({ payments });
    } catch (error) {
        console.error(error);
        res.status(500).json({ success: false, message: 'Error al obtener los pagos' });
    }
});

router.get('/payments/:id', async (req, res) => {
    try {
        const { id } = req.params;
        const paymentDoc = await Flete.doc(id).get();
        if (!paymentDoc.exists) {
            res.status(404).json({ success: false, message: 'Pago no encontrado' });
            return;
        }
        const payment = { id: paymentDoc.id, ...paymentDoc.data() };
        res.send({ payment });
    } catch (error) {
        console.error(error);
        res.status(500).json({ success: false, message: 'Error al obtener el pago' });
    }
});

router.put('/payments/:id', async (req, res) => {
    try {
        const { id } = req.params;
        const { body } = req;

        let updatedPayment;
        try {
            updatedPayment = JSON.parse(body);
        } catch (error) {
            throw new Error('Invalid JSON data in the request body');
        }

        await Flete.doc(id).update(updatedPayment);

        res.send({ success: true, message: 'Pago actualizado correctamente', payment: { id, ...updatedPayment } });
    } catch (error) {
        console.error(error);
        res.status(500).json({ success: false, message: 'Error al actualizar el pago' });
    }
});

router.delete('/payments/:id', async (req, res) => {
    try {
        const { id } = req.params;

        await Flete.doc(id).delete();

        res.send({ success: true, message: 'Pago eliminado correctamente' });
    } catch (error) {
        console.error(error);
        res.status(500).json({ success: false, message: 'Error al eliminar el pago' });
    }
});



router.post('/process-payment', csrfProtection, async (req, res) => {
    try {
        const { token, offerRate, fleteId, userId } = req.body;

        const userDoc = await User.doc(userId).get();
        if (!userDoc.exists) {
            res.status(404).json({ success: false, message: 'Usuario no encontrado' });
            return;
        }

        const fleteDoc = await Flete.doc(fleteId).get();
        if (!fleteDoc.exists) {
            res.status(404).json({ success: false, message: 'Flete no encontrado' });
            return;
        }

        const paymentIntent = await stripe.paymentIntents.create({
            amount: offerRate * 100, 
            currency: 'usd',
            payment_method: token,
            confirm: true,
        });

        const transactionData = {
            date: new Date(),
            amount: offerRate,
            paymentId: paymentIntent.id,
            userId: userId,
            fleteId: fleteId,
        };

        const fleteRef = Flete.doc(fleteId);
        const transactionCollectionRef = fleteRef.collection('transactions');
        await transactionCollectionRef.add(transactionData);

        res.json({ success: true, message: 'Pago procesado correctamente' });
    } catch (error) {
        console.error(error);
        res.status(500).json({ success: false, message: 'Error al procesar el pago' });
    }
});

module.exports = router;