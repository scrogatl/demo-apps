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
      CREATE TABLE IF NOT EXISTS users (
        id SERIAL PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        email VARCHAR(255) UNIQUE NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    // Insert sample users if table is empty
    const result = await pool.query('SELECT COUNT(*) FROM users');
    if (parseInt(result.rows[0].count) === 0) {
      await pool.query(`
        INSERT INTO users (name, email) VALUES
        ('Alice Smith', 'alice@example.com'),
        ('Bob Johnson', 'bob@example.com'),
        ('Charlie Brown', 'charlie@example.com'),
        ('Diana Prince', 'diana@example.com'),
        ('Eve Wilson', 'eve@example.com')
      `);
      console.log('Sample users created');
    }
  } catch (error) {
    console.error('Database initialization error:', error);
  }
}

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', service: 'user-service' });
});

// Get all users
app.get('/users', async (req, res) => {
  try {
    console.log('Fetching all users');
    const result = await pool.query('SELECT id, name, email FROM users ORDER BY id');
    console.log(`Found ${result.rows.length} users`);
    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching users:', error);
    res.status(500).json({ error: 'Failed to fetch users' });
  }
});

// Get user by ID
app.get('/users/:id', async (req, res) => {
  try {
    const userId = parseInt(req.params.id);
    console.log(`Fetching user ${userId}`);

    const result = await pool.query(
      'SELECT id, name, email FROM users WHERE id = $1',
      [userId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }

    console.log(`Found user: ${result.rows[0].name}`);
    res.json(result.rows[0]);
  } catch (error) {
    console.error('Error fetching user:', error);
    res.status(500).json({ error: 'Failed to fetch user' });
  }
});

// Create user
app.post('/users', async (req, res) => {
  try {
    const { name, email } = req.body;
    console.log(`Creating user: ${name} (${email})`);

    const result = await pool.query(
      'INSERT INTO users (name, email) VALUES ($1, $2) RETURNING id, name, email',
      [name, email]
    );

    console.log(`Created user ${result.rows[0].id}`);
    res.status(201).json(result.rows[0]);
  } catch (error) {
    console.error('Error creating user:', error);
    res.status(500).json({ error: 'Failed to create user' });
  }
});

const PORT = process.env.PORT || 3001;

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
    console.log(`User service listening on port ${PORT}`);
  });
}

startServer();
