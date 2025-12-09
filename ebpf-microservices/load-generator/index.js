const axios = require('axios');

const API_GATEWAY_URL = process.env.API_GATEWAY_URL || 'http://api-gateway:8080';
const REQUEST_INTERVAL = parseInt(process.env.REQUEST_INTERVAL || '5000', 10);
const ENABLE_CREATES = process.env.ENABLE_CREATES !== 'false';

const products = [
  'Laptop',
  'Mouse',
  'Keyboard',
  'Monitor',
  'Headphones',
  'Webcam',
  'USB Cable',
  'Docking Station',
  'Desk Lamp',
  'Chair'
];

function randomProduct() {
  return products[Math.floor(Math.random() * products.length)];
}

function randomAmount() {
  return Math.floor(Math.random() * 1000) + 10;
}

function randomUserId() {
  return Math.floor(Math.random() * 5) + 1;
}

async function makeRequest(method, path, data = null) {
  try {
    const config = {
      method,
      url: `${API_GATEWAY_URL}${path}`,
      timeout: 10000,
    };

    if (data) {
      config.data = data;
    }

    const response = await axios(config);
    console.log(`[${new Date().toISOString()}] ${method} ${path} - Status: ${response.status}`);
    return response.data;
  } catch (error) {
    if (error.response) {
      console.error(`[${new Date().toISOString()}] ${method} ${path} - Error: ${error.response.status} ${error.response.statusText}`);
    } else if (error.request) {
      console.error(`[${new Date().toISOString()}] ${method} ${path} - No response received`);
    } else {
      console.error(`[${new Date().toISOString()}] ${method} ${path} - Error: ${error.message}`);
    }
    return null;
  }
}

async function fetchUsers() {
  console.log('\n--- Fetching all users ---');
  await makeRequest('GET', '/users');
}

async function fetchUser() {
  const userId = randomUserId();
  console.log(`\n--- Fetching user ${userId} ---`);
  await makeRequest('GET', `/users/${userId}`);
}

async function fetchOrders() {
  console.log('\n--- Fetching all orders ---');
  await makeRequest('GET', '/orders');
}

async function createOrder() {
  if (!ENABLE_CREATES) {
    return;
  }

  const orderData = {
    user_id: randomUserId(),
    product: randomProduct(),
    amount: randomAmount()
  };

  console.log(`\n--- Creating order: ${orderData.product} for user ${orderData.user_id} ---`);
  await makeRequest('POST', '/orders', orderData);
}

async function userJourney() {
  console.log('\n=== Starting User Journey Path 1: Browse and Order ===');
  await fetchUsers();
  await sleep(500);
  await fetchUser();
  await sleep(500);
  await fetchOrders();
  await sleep(500);
  await createOrder();
}

async function adminJourney() {
  console.log('\n=== Starting User Journey Path 2: Admin View ===');
  await fetchOrders();
  await sleep(500);
  await fetchUsers();
  await sleep(500);
  await fetchUser();
}

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function runLoadGenerator() {
  console.log(`Starting load generator...`);
  console.log(`API Gateway URL: ${API_GATEWAY_URL}`);
  console.log(`Request Interval: ${REQUEST_INTERVAL}ms`);
  console.log(`Enable Creates: ${ENABLE_CREATES}`);

  let iteration = 0;

  while (true) {
    iteration++;
    console.log(`\n${'='.repeat(60)}`);
    console.log(`Iteration ${iteration}`);
    console.log('='.repeat(60));

    try {
      if (iteration % 2 === 0) {
        await userJourney();
      } else {
        await adminJourney();
      }
    } catch (error) {
      console.error('Error in load generation:', error.message);
    }

    console.log(`\nWaiting ${REQUEST_INTERVAL}ms before next iteration...`);
    await sleep(REQUEST_INTERVAL);
  }
}

console.log('Load Generator starting...');
console.log('Waiting 30 seconds for services to be ready...');

setTimeout(() => {
  runLoadGenerator().catch(error => {
    console.error('Fatal error in load generator:', error);
    process.exit(1);
  });
}, 30000);
