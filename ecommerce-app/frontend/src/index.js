

# Generate a boilerplate foundational index.js file
cat << 'EOF' > src/index.js
import React from 'react';
import ReactDOM from 'react-dom/client';

const App = () => {
  return (
    <div style={{ padding: '20px', fontFamily: 'sans-serif', textAlign: 'center' }}>
      <h1>🛒 3-Tier E-Commerce App</h1>
      <p>Frontend environment has successfully initialized!</p>
      <small>Connected to locally hosted architecture endpoints.</small>
    </div>
  );
};

const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
EOF

