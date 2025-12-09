const express = require('express');
const bodyParser = require('body-parser');
const { Pool } = require('pg');

const app = express();
app.use(bodyParser.json());

const pool = new Pool({
  host: process.env.DB_HOST || 'postgres',
  port: process.env.DB_PORT || 5432,
  database: process.env.DB_NAME || 'appdb',
  user: process.env.DB_USER || 'appuser',
  password: process.env.DB_PASSWORD || 'apppassword',
});

// Initialize database
async function initDB() {
  try {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS orders (
        id SERIAL PRIMARY KEY,
        user_id INTEGER NOT NULL,
        product VARCHAR(255) NOT NULL,
        amount DECIMAL(10, 2) NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    // Insert sample orders if table is empty
    const result = await pool.query('SELECT COUNT(*) FROM orders');
    if (parseInt(result.rows[0].count) === 0) {
      await pool.query(`
        INSERT INTO orders (user_id, product, amount) VALUES
        (1, 'Laptop', 999.99),
        (2, 'Mouse', 29.99),
        (1, 'Keyboard', 79.99),
        (3, 'Monitor', 299.99),
        (4, 'Headphones', 149.99)
      `);
      console.log('Sample orders created');
    }
  } catch (error) {
    console.error('Database initialization error:', error);
  }
}

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', service: 'order-service' });
});

// Get all orders
app.get('/orders', async (req, res) => {
  try {
    console.log('Fetching all orders');
    const result = await pool.query(
      'SELECT id, user_id, product, amount FROM orders ORDER BY id'
    );
    console.log(`Found ${result.rows.length} orders`);
    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching orders:', error);
    res.status(500).json({ error: 'Failed to fetch orders' });
  }
});

// Get orders by user ID
app.get('/orders/user/:userId', async (req, res) => {
  try {
    const userId = parseInt(req.params.userId);
    console.log(`Fetching orders for user ${userId}`);

    const result = await pool.query(
      'SELECT id, user_id, product, amount FROM orders WHERE user_id = $1 ORDER BY id',
      [userId]
    );

    console.log(`Found ${result.rows.length} orders for user ${userId}`);
    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching orders:', error);
    res.status(500).json({ error: 'Failed to fetch orders' });
  }
});

// Create order
app.post('/orders', async (req, res) => {
  try {
    const { user_id, product, amount } = req.body;
    console.log(`Creating order: ${product} for user ${user_id} (amount: ${amount})`);

    const result = await pool.query(
      'INSERT INTO orders (user_id, product, amount) VALUES ($1, $2, $3) RETURNING id, user_id, product, amount',
      [user_id, product, amount]
    );

    console.log(`Created order ${result.rows[0].id}`);
    res.status(201).json(result.rows[0]);
  } catch (error) {
    console.error('Error creating order:', error);
    res.status(500).json({ error: 'Failed to create order' });
  }
});

const PORT = process.env.PORT || 3002;

// Wait for database to be ready before starting server
async function startServer() {
  let retries = 30;
  const retryDelay = 5000;
  while (retries > 0) {
    try {
      await pool.query('SELECT 1');
      console.log('Database connection established');
      await initDB();
      break;
    } catch (error) {
      retries--;
      console.log(`Waiting for database... (${retries} retries left)`);
      if (retries > 0) {
        await new Promise(resolve => setTimeout(resolve, retryDelay));
      }
    }
  }

  if (retries === 0) {
    console.error('Could not connect to database after 150 seconds');
    process.exit(1);
  }

  app.listen(PORT, '0.0.0.0', () => {
    console.log(`Order service listening on port ${PORT}`);
  });
}

startServer();
