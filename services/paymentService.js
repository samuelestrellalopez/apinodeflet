const stripe = require('stripe')('sk_test_51Oc9WPHDirRzPkGPos2BoqHkUPjs9zZg0Za4IgAAkBIyGDtj0qK1HROr5z3cc2j0XW8KVBOeX6dC2OCpWUK374KF0067zscYfW');

const PaymentService = {


  
  generateToken: async (data) => {
    try {
      const { token, userEmail } = data; // Extraer el token de la tarjeta y el correo electrónico
  
      const existingCustomers = await stripe.customers.list({ email: userEmail });
  
      let customerId;
  
      if (existingCustomers.data.length > 0) {
        customerId = existingCustomers.data[0].id;
        await stripe.customers.createSource(customerId, { source: token });
      } else {
        const customer = await stripe.customers.create({
          email: userEmail,
          source: token 
        });
        console.log("Customer created:", customer);
        customerId = customer.id;
      }
  
      return customerId;
    } catch (error) {
      console.error("Error al generar el token:", error);
      throw error;
    }
  },
  
  

  addPaymentMethod: async (token, userEmail) => {
    try {
      // Busca el cliente existente con el correo electrónico proporcionado
      const customers = await stripe.customers.list({ email: userEmail });
      const existingCustomer = customers.data[0]; // Tomamos el primer cliente con el correo electrónico proporcionado
      
      // Si no se encontró ningún cliente existente, lanzamos un error
      if (!existingCustomer) {
        throw new Error("No se encontró ningún cliente con el correo electrónico proporcionado.");
      }
  
      // Agrega la fuente de pago al cliente existente
      const updatedCustomer = await stripe.customers.createSource(existingCustomer.id, { source: token.id });
  
      console.log("Customer updated with new payment method:", updatedCustomer);
    } catch (error) {
      console.error("Error al agregar método de pago:", error);
      throw error;
    }
  },
  

  listPaymentMethods: async (userEmail) => {
    try {
      const customers = await stripe.customers.list({
        email: userEmail,
      });
      const customer = customers.data[0];
      
      if (!customer) {
        throw new Error('No se encontró ningún cliente con el correo electrónico proporcionado.');
      }

      const paymentMethods = await stripe.paymentMethods.list({
        customer: customer.id,
        type: 'card',
      });

      const formattedPaymentMethods = paymentMethods.data.map(method => ({
        id: method.id,
        brand: method.card.brand,
        last4: method.card.last4,
        expMonth: method.card.exp_month,
        expYear: method.card.exp_year,
        cvcCheck: method.card.checks.cvc_check === 'pass' ? 'Verificado' : 'No verificado',
      }));
      
      return formattedPaymentMethods;
    } catch (error) {
      console.error("Error al listar métodos de pago:", error);
      throw error;
    }
  },







generateTokenWithCardData: async (cardData, userEmail) => {
  try {
    // Primero creamos el token utilizando los datos de la tarjeta
    const token = await PaymentService.createToken(cardData);
    
    // Luego agregamos el método de pago al cliente asociado al correo electrónico proporcionado
    await PaymentService.addPaymentMethod(token, userEmail);
    
    // Devolvemos el ID del token generado
    return token.id;
  } catch (error) {
    console.error("Error al generar el token con los datos de la tarjeta:", error);
    throw error;
  }
}
}


module.exports = PaymentService;
