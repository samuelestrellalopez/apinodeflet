const firebase = require('firebase/compat/app');
require('firebase/compat/database');  
require('firebase/compat/storage');
const crypto = require('crypto');



module.exports = {
    JWT_SECRET: crypto.randomBytes(32).toString('hex'),  
};

module.exports = {
    stripeSecretKey: 'sk_test_51Oc9WPHDirRzPkGPos2BoqHkUPjs9zZg0Za4IgAAkBIyGDtj0qK1HROr5z3cc2j0XW8KVBOeX6dC2OCpWUK374KF0067zscYfW',
    stripePublicKey: 'pk_test_51OcJloAIqkgFr3utXpc2XaMyAIP306DVAZoaDw2IjGk3ZOwjUZ5p8w3CIvHH6UxpLSOLn22gTSEejSetbQlg2vpp00tlbZKxmg',
  };
  
  
    const firebaseConfig = {
      apiKey: "AIzaSyAD6HS5Hx9mVJrxgH0rbpQ2lU4cvCO_NGg",
      authDomain: "apiflet.firebaseapp.com",
      databaseURL: "https://apiflet-default-rtdb.firebaseio.com/", 
      storageBucket: "apiflet.appspot.com",
      messagingSenderId: "364633043807",
      appId: "1:364633043807:web:fdf0fb9e70f1f298833cea",
      measurementId: "G-Y64HPLF58M"
    };

  
 try {
    firebase.initializeApp(firebaseConfig);
} catch (error) {
    console.error('Firebase initialization error:', error.stack);
}

const db = firebase.database();  
const Driver = db.ref("Drivers");  
const Flete = db.ref("Fletes");    
const User = db.ref("Users");      

const storage = firebase.storage();

module.exports = {
  User,
  Driver,
  Flete,
  storage
};