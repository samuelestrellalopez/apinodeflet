const express = require('express');
const cors = require('cors');
const cookieParser = require('cookie-parser');
const csrf = require('csurf');
const app = express();
const driverController = require('./controllers/driverController');
const fleteController = require('./controllers/fleteController');
const userController = require('./controllers/usercontroller.js');
const paymentController = require('./controllers/paymentController');
const crypto = require('crypto');

const secretKey = crypto.randomBytes(32).toString('hex');
process.env.JWT_SECRET = secretKey;

app.use(express.json());
app.use(cors());
app.use(cookieParser());

const csrfProtection = csrf({ cookie: true });

app.use('/api', userController);
app.use('/api', driverController);
app.use('/api', fleteController);

// Ruta de manejo del pago
app.use('/api', paymentController);

// Inicia el servidor
app.listen(4000, () => console.log('Up and Running port 4000'));
