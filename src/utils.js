require('dotenv').config();
const axios = require('axios');
const BASE_URL = 'https://api.archerdao.io';
const transactionPath = 'v1/transaction';
const gasPath = 'v1/gas';
let initBody = {
    "jsonrpc": "2.0",
    "method": "archer_submitTx"
}

async function submitArcherTransaction(tx, deadline) {
    const url = `${BASE_URL}/${transactionPath}`;
    const id = (new Date()).getTime();
    const body = Object.assign({ tx, deadline, id }, initBody);
    const response = await axios({
        method: 'post',
        url: url,
        headers: {
            'Authorization': process.env.ARCHER_DAO_API_KEY,
            'Content-Type': 'application/json'
        },
        data: body
    });
    if (!response) {
        console.log('Error sending transaction to Archer relay');
        process.exit(1);
    }

    return response;
}

async function getArcherMinerTips() {
    const url = `${BASE_URL}/${gasPath}`;
    const response = await axios({
        method: 'get',
        url: url,
        headers: {
            'Content-Type': 'application/json',
            'Referrer-Policy': 'no-referrer'
        }
    });

    return response.data.data;
}

async function getTip(speed= 'standard') {
    const tips = await getArcherMinerTips();
    if (!tips) {
        console.log(`Couldn't get Archer gas`);
        process.exit(1);
    }
    switch (speed) {
        case 'immediate': return tips['immediate'];
        case 'rapid': return tips['rapid'];
        case 'fast': return tips['fast']
        case 'standard': return tips['standard'];
        case 'slow': return tips['slow'];
        case 'slower': return tips['slower'];
        case 'slowest': return tips['slowest'];
        default: return tips['standard'];
    }
}

module.exports = {
    submitArcherTransaction,
    getTip
}