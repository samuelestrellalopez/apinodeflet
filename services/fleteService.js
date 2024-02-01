const { Flete, User } = require('../config/config');

async function addFlete(newFlete) {
    try {
        const userSnapshot = await User.child(newFlete.userId).once('value');

        if (!userSnapshot.exists()) {
            throw new Error('User not found');
        }

        const fleteRef = await Flete.push(newFlete);
        const fleteId = fleteRef.key;

        await Flete.child(fleteId).update({ id: fleteId });

        return { id: fleteId, ...newFlete };
    } catch (error) {
        throw error;
    }
}


async function getFletes() {
    const fletesSnapshot = await Flete.once('value');
    return Object.keys(fletesSnapshot.val() || {}).map((id) => ({ id, ...fletesSnapshot.val()[id] }));
}

async function getFleteById(id) {
    const fleteSnapshot = await Flete.child(id).once('value');
    if (!fleteSnapshot.exists()) {
        throw new Error('Flete not found');
    }
    return { id, ...fleteSnapshot.val() };
}

async function updateFlete(id, updatedFlete) {
    const existingFlete = await Flete.child(id).once('value');

    if (existingFlete.exists()) {
        await Flete.child(id).update(updatedFlete);
    } else {
        throw new Error('Flete not found');
    }
}

async function deleteFlete(id) {
    await Flete.child(id).remove();
}


function generateToken(fleteId) {
    const secretKey = process.env.JWT_SECRET;
    const token = jwt.sign({ fleteId }, secretKey, { expiresIn: '1h' });
    return token;
}

module.exports = {
    addFlete,
    getFletes,
    getFleteById,
    updateFlete,
    deleteFlete,
    generateToken,
};
