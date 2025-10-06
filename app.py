#!/usr/bin/env python3
"""
Simple Flask Web Application for GCP Technical Test
Escenario 3: CI/CD with Cloud Build and Cloud Run
"""

from flask import Flask, render_template_string, request, jsonify
import os
import datetime

app = Flask(__name__)

# HTML Template
HTML_TEMPLATE = """
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>GCP Technical Test - Escenario 3</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            color: #333;
        }
        
        .container {
            background: white;
            padding: 3rem;
            border-radius: 20px;
            box-shadow: 0 20px 40px rgba(0,0,0,0.1);
            max-width: 800px;
            width: 90%;
            text-align: center;
        }
        
        .header {
            margin-bottom: 2rem;
        }
        
        .title {
            color: #4285f4;
            font-size: 2.5rem;
            margin-bottom: 1rem;
            font-weight: 700;
        }
        
        .subtitle {
            color: #666;
            font-size: 1.2rem;
            margin-bottom: 2rem;
        }
        
        .info-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 1.5rem;
            margin: 2rem 0;
        }
        
        .info-card {
            background: #f8f9fa;
            padding: 1.5rem;
            border-radius: 10px;
            border-left: 4px solid #4285f4;
        }
        
        .info-card h3 {
            color: #4285f4;
            margin-bottom: 0.5rem;
        }
        
        .status {
            display: inline-block;
            padding: 0.5rem 1rem;
            border-radius: 25px;
            font-weight: bold;
            margin: 1rem 0;
        }
        
        .status.success {
            background: #d4edda;
            color: #155724;
        }
        
        .features {
            text-align: left;
            margin: 2rem 0;
        }
        
        .features h3 {
            color: #4285f4;
            margin-bottom: 1rem;
        }
        
        .features ul {
            list-style: none;
            padding: 0;
        }
        
        .features li {
            padding: 0.5rem 0;
            border-bottom: 1px solid #eee;
        }
        
        .features li:before {
            content: "✅ ";
            margin-right: 0.5rem;
        }
        
        .footer {
            margin-top: 2rem;
            padding-top: 2rem;
            border-top: 1px solid #eee;
            color: #666;
        }
        
        .api-section {
            background: #f8f9fa;
            padding: 1.5rem;
            border-radius: 10px;
            margin: 2rem 0;
        }
        
        .api-section h3 {
            color: #4285f4;
            margin-bottom: 1rem;
        }
        
        .api-endpoint {
            background: #e9ecef;
            padding: 0.5rem;
            border-radius: 5px;
            font-family: monospace;
            margin: 0.5rem 0;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1 class="title">🚀 GCP Technical Test</h1>
            <p class="subtitle">Escenario 3: CI/CD con Cloud Build y Cloud Run</p>
            <div class="status success">✅ Aplicación Desplegada Exitosamente</div>
        </div>
        
        <div class="info-grid">
            <div class="info-card">
                <h3>🌐 Servicio</h3>
                <p>Cloud Run</p>
            </div>
            <div class="info-card">
                <h3>🔧 CI/CD</h3>
                <p>Cloud Build</p>
            </div>
            <div class="info-card">
                <h3>🐳 Container</h3>
                <p>Docker + Artifact Registry</p>
            </div>
            <div class="info-card">
                <h3>🔒 Seguridad</h3>
                <p>Cloud Armor + IAM</p>
            </div>
        </div>
        
        <div class="features">
            <h3>🏗️ Arquitectura Implementada</h3>
            <ul>
                <li>Repositorio GitHub con aplicación Flask</li>
                <li>Pipeline CI/CD con Cloud Build</li>
                <li>Despliegue automático en Cloud Run</li>
                <li>Imagen Docker en Artifact Registry</li>
                <li>Tráfico HTTPS obligatorio</li>
                <li>Rol IAM personalizado para Cloud Run</li>
                <li>Política Cloud Armor para bloqueo de IPs</li>
                <li>Monitoreo y logging integrado</li>
            </ul>
        </div>
        
        <div class="api-section">
            <h3>🔌 API Endpoints</h3>
            <div class="api-endpoint">GET / - Página principal</div>
            <div class="api-endpoint">GET /health - Estado del servicio</div>
            <div class="api-endpoint">GET /info - Información del sistema</div>
            <div class="api-endpoint">GET /api/status - Estado JSON</div>
        </div>
        
        <div class="footer">
            <p><strong>Desplegado el:</strong> {{ deployment_time }}</p>
            <p><strong>Versión:</strong> {{ version }}</p>
            <p><strong>Entorno:</strong> {{ environment }}</p>
        </div>
    </div>
</body>
</html>
"""

@app.route('/')
def home():
    """Página principal de la aplicación"""
    return render_template_string(HTML_TEMPLATE, 
                                deployment_time=datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S UTC"),
                                version="1.0.0",
                                environment="Production")

@app.route('/health')
def health():
    """Endpoint de salud para Cloud Run"""
    return jsonify({
        "status": "healthy",
        "timestamp": datetime.datetime.now().isoformat(),
        "service": "gcp-technical-test",
        "version": "1.0.0"
    })

@app.route('/info')
def info():
    """Información del sistema"""
    return jsonify({
        "service": "GCP Technical Test - Escenario 3",
        "version": "1.0.0",
        "environment": "Production",
        "platform": "Google Cloud Run",
        "deployment_time": datetime.datetime.now().isoformat(),
        "features": [
            "CI/CD with Cloud Build",
            "Container deployment",
            "HTTPS enforcement",
            "Cloud Armor security",
            "Custom IAM roles"
        ]
    })

@app.route('/api/status')
def api_status():
    """API endpoint para verificar el estado"""
    client_ip = request.headers.get('X-Forwarded-For', request.remote_addr)
    
    return jsonify({
        "status": "operational",
        "timestamp": datetime.datetime.now().isoformat(),
        "client_ip": client_ip,
        "user_agent": request.headers.get('User-Agent', 'Unknown'),
        "service_info": {
            "name": "gcp-technical-test",
            "version": "1.0.0",
            "environment": "production"
        }
    })

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port, debug=False)
