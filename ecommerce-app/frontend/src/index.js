import React, { useState, useEffect } from 'react';
import ReactDOM from 'react-dom/client';

function App() {
  const [products, setProducts] = useState([]);
  const [error, setError] = useState(null);

  useEffect(() => {
    // Fetches live data directly from your backend API container
    fetch('http://localhost:5000/api/products')
      .then((res) => {
        if (!res.ok) throw new Error('Network response was not ok');
        return res.json();
      })
      .then((data) => setProducts(data))
      .catch((err) => setError(err.message));
  }, []);

  return (
    <div style={{ padding: '40px', fontFamily: 'Arial, sans-serif', maxWidth: '800px', margin: '0 auto' }}>
      <header style={{ borderBottom: '2px solid #eee', paddingBottom: '20px', marginBottom: '30px' }}>
        <h1 style={{ color: '#2c3e50', margin: 0 }}>🛒 Local 3-Tier E-Commerce Stack</h1>
        <p style={{ color: '#7f8c8d', marginTop: '5px' }}>Testing Environment: Docker Desktop</p>
        <div style={{ display: 'inline-block', padding: '6px 12px', borderRadius: '20px', background: '#2ecc71', color: '#fff', fontSize: '14px', fontWeight: 'bold' }}>
          ● Connected to Live Database
        </div>
      </header>

      <main>
        <h2 style={{ color: '#34495e' }}>Available Inventory</h2>
        {error && <p style={{ color: '#e74c3c' }}>Error fetching data: {error}</p>}
        
        <div style={{ display: 'grid', gap: '20px', marginTop: '20px' }}>
          {products.map((product) => (
            <div key={product.id} style={{ border: '1px solid #e0e0e0', borderRadius: '8px', padding: '20px', boxShadow: '0 2px 4px rgba(0,0,0,0.05)' }}>
              <h3 style={{ margin: '0 0 10px 0', color: '#2c3e50' }}>{product.name}</h3>
              <p style={{ margin: '5px 0', fontWeight: 'bold', color: '#e67e22' }}>Price: ${product.price}</p>
              <p style={{ margin: '5px 0', color: '#7f8c8d', fontSize: '14px' }}>In Stock: {product.stock} units</p>
            </div>
          ))}
        </div>
      </main>
    </div>
  );
}

const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);

