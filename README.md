# opusmt-docker-init

A lightweight Dockerized **OPUS-MT** translation server for:

- **Greek ↔ English**
- **Chinese ↔ English**
- **Chinese ↔ Greek** (via English pivot)

Optimized for quick local deployment and offline use on **Debian** systems.  
Suitable for both virtualized and bare-metal environments.

---

## ✨ Features

- 🗣 **High-quality Greek translations** using OPUS-MT models trained on EU/UN official documents
- 🔄 **Pivot translation** for Chinese ↔ Greek via English for better accuracy
- 📦 **Dockerized** for easy deployment and isolation
- 🔌 **REST API** with `/translate` endpoint
- 🛡 **Offline capable** after initial model download
- 🔁 **Auto-restart** on system reboot

---

## 📋 Requirements

- Debian 11/12 (or compatible Linux)
- Docker
- Docker Compose
- ~3 GB free disk space (for models)
- ≥ 2 CPU cores, ≥ 4 GB RAM recommended

---

## 🚀 Quick Start

### Option 1: One‑click deploy (recommended)
For users who want to get started quickly — this single command will install dependencies, clone the repo, build the image, start the service, and run the quick test automatically.

```bash
curl -O https://raw.githubusercontent.com/gzdanny/opusmt-docker-init/main/deploy-and-test.sh && bash deploy-and-test.sh
```
> The first run will take a few minutes as it downloads Docker base images and translation models.

---

### Option 2: Manual deployment
For users who want to customize the setup or understand each step in detail.

1. **Install dependencies** (Debian):
   ```bash
   sudo apt update && sudo apt upgrade -y
   sudo apt install -y docker.io docker-compose git
   sudo systemctl enable --now docker
   ```

2. **Clone this repository**:
   ```bash
   git clone https://github.com/gzdanny/opusmt-docker-init.git
   cd opusmt-docker-init
   ```

3. **Build and run**:
   ```bash
   sudo docker-compose build
   sudo docker-compose up -d
   ```

4. **Check status**:
   ```bash
   sudo docker ps
   ```

5. **Run quick test** (optional but recommended):  
   This sends several sample translation requests to verify that the service is functioning correctly.
   ```bash
   chmod +x quick-test.sh
   ./quick-test.sh
   ```
   > If you changed the host port in `docker-compose.yml`, run:  
   > `./quick-test.sh localhost <new-port>`

---

## 🌐 API Usage

### Endpoint
```
POST /translate
Content-Type: application/json
```

### Request body
```json
{
  "q": "Καλημέρα σας",
  "source": "el",
  "target": "en"
}
```
- `source`: `"auto"`, `"el"`, `"en"`, `"zh"`
- `target`: `"el"`, `"en"`, `"zh"`
- `max_new_tokens` *(optional)*: limit output length

### Example (CLI)
```bash
curl -s -X POST http://<server-ip>:8000/translate \
  -H "Content-Type: application/json" \
  -d '{"q":"Καλημέρα σας","source":"el","target":"en"}'
```

### Example response
```json
{
  "translatedText": "Good morning to you",
  "route": ["el->en"],
  "detectedSource": "el"
}
```

---

## 📊 Translation Routes

| Source | Target | Route Used |
|--------|--------|------------|
| el     | en     | el→en      |
| en     | el     | en→el      |
| zh     | en     | zh→en      |
| en     | zh     | en→zh      |
| zh     | el     | zh→en→el   |
| el     | zh     | el→en→zh   |

---

## ⚡ Performance Notes

- **First request** may be slower due to model loading
- CPU inference: ~0.3–1s for short sentences
- Memory usage: ~2–3 GB for 4 models
- For faster CPU inference, consider converting models to [CTranslate2](https://opennmt.net/CTranslate2/)

---

## 🔒 Security

- Designed for **local/internal network** use
- If exposing to the internet:
  - Use HTTPS (via reverse proxy like Nginx)
  - Restrict access by IP or API key

---

## 📜 License

This project is licensed under the **Apache License 2.0**.

- **Project code** (Dockerfile, app.py, docker-compose.yml, and related scripts) is © 2025 by Danny, released under the Apache License 2.0.
- **Translation models** are from [Helsinki-NLP/OPUS-MT](https://huggingface.co/Helsinki-NLP) and are also licensed under the Apache License 2.0.
- You are free to use, modify, and distribute this project for personal, academic, or commercial purposes, provided that you retain the copyright notices and license terms.

For the full license text, see the [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0).

---

## 🙌 Acknowledgements

- [OPUS-MT](https://opus.nlpl.eu/Opus-MT.php) for high-quality multilingual models
- [Hugging Face Transformers](https://huggingface.co/transformers/) for model hosting and APIs
- [FastAPI](https://fastapi.tiangolo.com/) for the web framework
```
