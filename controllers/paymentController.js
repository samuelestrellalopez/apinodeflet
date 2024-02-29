const express = require('express');
const router = express.Router();
const PaymentService = require('../services/paymentService');



router.post('/generate-token', async (req, res) => {
  try {
    const { cardData, userEmail } = req.body; // Se espera que la solicitud incluya los datos de la tarjeta y el correo electrónico del usuario
    const token = await PaymentService.generateTokenWithCardData(cardData, userEmail); // Utiliza el servicio para generar el token con los datos de la tarjeta
    res.status(200).json({ token }); // Devuelve el token generado en la respuesta
  } catch (error) {
    console.error("Error en la solicitud de generación de token:", error);
    res.status(500).json({ error: "Error en la solicitud de generación de token" }); // Si hay algún error, devuelve un error interno del servidor
  }
});


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


router.post('/add_payment_method', async (req, res) => {
  try {
    const { token, userEmail } = req.body;
    const customerId = await PaymentService.addPaymentMethod(token, userEmail); // Actualizado para capturar el ID del cliente
    res.json({ success: true, customerId: customerId });
  } catch (error) {
    console.error("Error al agregar método de pago:", error);
    res.status(500).json({ success: false, error: 'Failed to add payment method' });
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

module.exports = router;
