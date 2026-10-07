import React, { useEffect, useState } from 'react';
import io from 'socket.io-client';

// In production, this will point to your AWS Load Balancer URL
const BACKEND_URL = process.env.REACT_APP_BACKEND_URL || 'http://localhost:5000';
const socket = io(BACKEND_URL);

function App() {
  const [products, setProducts] = useState([]);

  useEffect(() => {
    // 1. Fetch initial products over standard REST API
    fetch(`${BACKEND_URL}/api/products`)
      .then(res => res.json())
      .then(data => setProducts(data))
      .catch(err => console.error(err));

    // 2. Listen for Real-Time Stock Updates via WebSockets
    socket.on('stockUpdate', (data) => {
      setProducts(prevProducts => 
        prevProducts.map(p => p.id === data.productId ? { ...p, stock: data.newStock } : p)
      );
    });

    return () => socket.off('stockUpdate');
  }, []);

  return (
    <div style={{ padding: '20px', fontFamily: 'Arial' }}>
      <h1>⚡ Real-Time E-Commerce Shop</h1>
      <div style={{ display: 'flex', gap: '20px' }}>
        {products.map(product => (
          <div key={product.id} style={{ border: '1px solid #ccc', padding: '15px', borderRadius: '8px' }}>
            <h3>{product.name}</h3>
            <p>Price: \${product.price}</p>
            <p style={{ color: product.stock < 3 ? 'red' : 'black', fontWeight: 'bold' }}>
              Stock: {product.stock} left
            </p>
          </div>
        ))}
      </div>
    </div>
  );
}

export default App;

