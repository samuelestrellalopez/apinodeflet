const express = require('express');
const router = express.Router();
const PaymentService = require('../services/paymentService');
const stripe = require('stripe')('pk_test_51Oc9WPHDirRzPkGPs7RVgxaLXz7ZEpmeULsvZQsk5xDhtFPST7ke5TDCH03H444ijUW5xFcIt5R6YUSLEctCxlzG00ASdfAHZx'); // Aquí debes colocar tu clave secreta de Stripe





router.post('/generate_token2', async (req, res) => {
  try {
    const { token, userEmail } = req.body; // Incluye userEmail en la desestructuración
    const tokenId = await PaymentService.generateToken({ token, userEmail }); // Pasa el objeto completo al servicio
    res.json({ success: true, tokenId: tokenId   });
  } catch (error) {
    console.error("Error al generar el token:", error);
    res.status(500).json({ success: false, error: 'Failed to generate token' });
  }
});




router.get('/payment-methods/:userEmail', async (req, res) => {
  try {
    const userEmail = req.params.userEmail;
    const paymentMethods = await PaymentService.listPaymentMethods(userEmail);
    res.json(paymentMethods);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

router.post('/generate_tokent', async (req, res) => {
    try {
        const { cardNumber, cardExpiry, cardCvc } = req.body;

        // Crear un token utilizando la API de Stripe
        const token = await stripe.tokens.create({
            card: {
                number: cardNumber,
                exp_month: cardExpiry.month,
                exp_year: cardExpiry.year,
                cvc: cardCvc
            },
        });

        
        res.status(200).json({ token: token.id });
    } catch (error) {
        console.error('Error generando token con Stripe:', error);
        res.status(500).json({ error: 'Error generando token con Stripe' });
    }
});


router.delete('/payment-methods/:paymentMethodId', async (req, res) => {
  try {
    const paymentMethodId = req.params.paymentMethodId;

    // Llamar al servicio para eliminar el método de pago
    await PaymentService.deletePaymentMethod(paymentMethodId);

    res.status(200).json({ message: 'Payment method deleted successfully' });
  } catch (error) {
    console.error('Error deleting payment method:', error);
    res.status(500).json({ error: 'Error deleting payment method' });
  }
});

module.exports = router;
