# Bare-metal Local Deployment

**One‑click run on Debian:**
```bash
curl -s https://raw.githubusercontent.com/gzdanny/opusmt-docker-init/main/baremetal/deploy_local.sh | bash
```
> Append a port number to change the default (8888):
```bash
curl -s https://raw.githubusercontent.com/gzdanny/opusmt-docker-init/main/baremetal/deploy_local.sh | bash -s -- 9000
```

---

This directory contains scripts for running the OPUS-MT translation server **directly on a Debian-based machine** without Docker.  
It is intended for **development and debugging purposes only**.  
For production deployment, please use the Docker setup in the root of this repository.

---

## deploy_local.sh

### Description
`deploy_local.sh` automates the setup and launch of the translation server on a bare-metal Debian system.  
It replicates the environment defined in the Dockerfile but runs natively on the host OS.

### Features
- Installs required system packages
- Clones or updates the project repository
- Creates and activates a Python virtual environment
- Installs Python dependencies (matching the Dockerfile)
- Starts the FastAPI server with `uvicorn` in reload mode for live code changes

### Usage
```bash
# Default port 8888
bash baremetal/deploy_local.sh

# Custom port (e.g., 9000)
bash baremetal/deploy_local.sh 9000
```

Once started, the API documentation will be available at:
```
http://<server-ip>:<port>/docs
```

### Notes
- This setup is for **local development/debugging** only.
- Code changes to `app.py` will be automatically reloaded.
- If you need the service to run in the background, consider using `tmux`, `screen`, or `nohup`.
