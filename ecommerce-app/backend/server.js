//tes
const express = require('express');
const mysql = require('mysql2');
const cors = require('cors');
const http = require('http');
const { Server } = require('socket.io');

const app = express();
app.use(cors());
app.use(express.json());

const server = http.createServer(app);
const io = new Server(server, {
    cors: { origin: "*" } // In production, restrict this to your frontend URL
});

// MySQL Connection Configuration
// We use environment variables so Kubernetes can easily inject them later!
const db = mysql.createPool({
    host: process.env.DB_HOST || 'localhost',
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || 'password',
    database: process.env.DB_NAME || 'ecommerce',
    waitForConnections: true,
    connectionLimit: 10
});

// Rest API Endpoint to get products
app.get('/api/products', (req, res) => {
    db.query('SELECT * FROM products', (err, results) => {
        if (err) return res.status(500).json(err);
        res.json(results);
    });
});

// Real-time Event: Simulate an admin updating stock
app.post('/api/products/stock', (req, res) => {
    const { productId, newStock } = req.body;
    db.query('UPDATE products SET stock = ? WHERE id = ?', [newStock, productId], (err) => {
        if (err) return res.status(500).json(err);
        
        // Broadcast the real-time update to all connected React clients
        io.emit('stockUpdate', { productId, newStock });
        res.json({ message: 'Stock updated and broadcasted!' });
    });
});

io.on('connection', (socket) => {
    console.log(`User connected: ${socket.id}`);
});

const PORT = process.env.PORT || 5000;
server.listen(PORT, () => console.log(`Backend server running on port ${PORT}`));

