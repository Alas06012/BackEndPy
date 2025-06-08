#!/bin/bash

# Ejecuta tu aplicación Flask en segundo plano
python run.py --host=0.0.0.0 &

# Espera unos segundos para que Flask levante
sleep 5

# Ejecuta el curl a la API de DeepSeek
echo "==> Haciendo prueba de conexión a DeepSeek"
curl -X POST https://api.deepseek.com/chat/completions \
  -H "Authorization: Bearer $DEEPSEEK_APIKEY" \
  -H "Content-Type: application/json" \
  -d '{
        "model": "deepseek-chat",
        "messages": [
          {"role": "system", "content": "Eres un asistente útil."},
          {"role": "user", "content": "¿Cuál es la capital de Francia?"}
        ]
      }'

# Mantiene el contenedor vivo (espera que Flask muera, si lo hace)
wait
