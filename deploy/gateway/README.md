# LAN Multi-Application Staging Gateway Documentation

## 1. Overview & Architecture
This gateway provides a centralized, path-based reverse proxy on **`http://192.168.0.200:8080/`** for multi-application testing across the private local area network (LAN).

Each application on the host runs in its own isolated Docker Compose project, internal bridge network, and persistent storage volume, while joining the shared external bridge network **`lan_gateway_net`** to expose its web and API routes through the gateway.

### Network Topology
```
                          LAN Host: 192.168.0.200
  ┌───────────────────────────────────────────────────────────────────────┐
  │ Port 8080: lan-gateway (Nginx:1.27-alpine)                            │
  └───────────────────┬───────────────────────────────┬───────────────────┘
                      │ (lan_gateway_net)             │ (lan_gateway_net)
                      ▼                               ▼
       ┌─────────────────────────────┐  ┌─────────────────────────────┐
       │ Roomlyst (Port 8081 direct) │  │ NutriLens (Port 8082 future)│
       │ Container: roomlyst-api     │  │ Container: nutrilens-api    │
       │ Network: roomlyst_net       │  │ Network: nutrilens_net      │
       │ Volume: roomlyst_data       │  │ Volume: nutrilens_data      │
       │ Path: /roomlyst/            │  │ Path: /nutrilens/           │
       └─────────────────────────────┘  └─────────────────────────────┘
```

---

## 2. Port Allocation Registry

| Service / Application | Slug / Path | Gateway Route | Dedicated Direct Host Port | Compose Project | Status |
|:---|:---:|:---:|:---:|:---:|:---:|
| **Shared LAN Gateway** | `/` | `http://192.168.0.200:8080/` | `8080` | `lan-gateway` | **Active** |
| **Roomlyst Studio** | `/roomlyst/` | `http://192.168.0.200:8080/roomlyst/` | `8081` | `roomlyst` | **Active** |
| **NutriLens (Planned)** | `/nutrilens/` | `http://192.168.0.200:8080/nutrilens/` | `8082` | `nutrilens` | *Template Only* |
| **Next App Slot** | `/app-slug/` | `http://192.168.0.200:8080/<slug>/` | `8083` | `<app-name>` | *Reserved* |

---

## 3. How to Onboard a New Application

To register a new application on the staging server without disrupting active workloads:

### Step 1: Ensure `lan_gateway_net` is Declared
In the new application's `docker-compose.yml`, join the external gateway network:
```yaml
networks:
  app_internal_net:
    name: <app-name>_net
    driver: bridge
  lan_gateway_net:
    name: lan_gateway_net
    external: true
```

### Step 2: Add Location Block to `deploy/gateway/nginx.conf`
Add a dedicated subpath proxy block:
```nginx
location = /<app-slug> {
    return 301 /<app-slug>/;
}

location /<app-slug>/ {
    proxy_pass http://<container-name>:<internal-port>/;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-Prefix /<app-slug>;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection $connection_upgrade;
}
```

### Step 3: Reload Gateway Without Downtime
Execute an in-flight reload of Nginx:
```bash
docker --context home-server exec lan-gateway nginx -s reload
```

---

## 4. Operational & Rollback Procedures

### Gateway Restart / Maintenance
```bash
docker --context home-server compose -f deploy/gateway/docker-compose.yml restart
```

### Gateway Rollback (Reverting to Direct Container Binding)
If the gateway is ever taken offline:
```bash
docker --context home-server compose -f deploy/gateway/docker-compose.yml down
# Rebind Roomlyst to port 8080:
ROOMLYST_PORT=8080 docker --context home-server compose up -d
```
