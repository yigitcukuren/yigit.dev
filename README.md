# yigit.dev

The static homepage at `yigit.dev` and personal self-hosted services run on the Hetzner server `188.245.16.94` (Ubuntu 26.04). Caddy serves the homepage and terminates HTTPS. Wallos runs in Docker at `s.yigit.dev`; its container port is bound only to the server's loopback interface.

## Repository layout

- `index.html`: homepage, with no build step or JavaScript dependencies.
- `infra/Caddyfile`: production HTTPS configuration for the homepage, `www` redirect, and Wallos reverse proxy.
- The Wallos Caddy route adds HSTS and marks upstream cookies `Secure` so browsers send them only over HTTPS.
- The Wallos route sends `X-Robots-Tag: noindex, nofollow` on all responses. Its `robots.txt` permits crawling so search engines can read that directive. The Wallos login page is still publicly reachable; `noindex` is not an access control.
- `infra/Caddyfile.staging`: temporary IP-based homepage configuration before DNS changes.
- `infra/Caddyfile.homepage`: serves the domain during cutover while Wallos account setup remains private.
- `infra/bootstrap.sh`: one-time Ubuntu installation of Docker, the Compose plugin, and Caddy from their official apt repositories.
- `infra/wallos/compose.yaml`: pinned Wallos image and persistent bind mounts.

## Deploy

Use the existing SSH key `~/.ssh/id_ed25519_hetzner`. The private key stays outside this repository. Run these commands from the repository root:

```sh
scp -i ~/.ssh/id_ed25519_hetzner -o IdentitiesOnly=yes -o BatchMode=yes infra/bootstrap.sh root@188.245.16.94:/tmp/yigit-bootstrap.sh
ssh -i ~/.ssh/id_ed25519_hetzner -o IdentitiesOnly=yes -o BatchMode=yes root@188.245.16.94 'bash /tmp/yigit-bootstrap.sh'
ssh -i ~/.ssh/id_ed25519_hetzner -o IdentitiesOnly=yes -o BatchMode=yes root@188.245.16.94 'mkdir -p /srv/yigit.dev/site /srv/wallos'
scp -i ~/.ssh/id_ed25519_hetzner -o IdentitiesOnly=yes -o BatchMode=yes index.html root@188.245.16.94:/srv/yigit.dev/site/index.html
scp -i ~/.ssh/id_ed25519_hetzner -o IdentitiesOnly=yes -o BatchMode=yes infra/wallos/compose.yaml root@188.245.16.94:/srv/wallos/compose.yaml
ssh -i ~/.ssh/id_ed25519_hetzner -o IdentitiesOnly=yes -o BatchMode=yes root@188.245.16.94 'cd /srv/wallos && docker compose up -d'
```

Before DNS is changed, serve the homepage by IP with the staging Caddyfile:

```sh
scp -i ~/.ssh/id_ed25519_hetzner -o IdentitiesOnly=yes -o BatchMode=yes infra/Caddyfile.staging root@188.245.16.94:/etc/caddy/Caddyfile
ssh -i ~/.ssh/id_ed25519_hetzner -o IdentitiesOnly=yes -o BatchMode=yes root@188.245.16.94 'caddy validate --config /etc/caddy/Caddyfile && systemctl reload caddy'
```

Before changing DNS, switch to the homepage cutover configuration. It serves `yigit.dev` and redirects `www`, while the Wallos hostname stays closed:

```sh
scp -i ~/.ssh/id_ed25519_hetzner -o IdentitiesOnly=yes -o BatchMode=yes infra/Caddyfile.homepage root@188.245.16.94:/etc/caddy/Caddyfile
ssh -i ~/.ssh/id_ed25519_hetzner -o IdentitiesOnly=yes -o BatchMode=yes root@188.245.16.94 'caddy validate --config /etc/caddy/Caddyfile && systemctl reload caddy'
```

Wallos needs an account on first run. Create it through a local SSH tunnel **before** enabling its public Caddy route:

```sh
ssh -i ~/.ssh/id_ed25519_hetzner -o IdentitiesOnly=yes -L 8282:127.0.0.1:8282 root@188.245.16.94
```

Then open `http://127.0.0.1:8282` in a browser, create the first account, and close the tunnel. In the Wallos admin settings, disable public registration once the intended accounts exist.

After the Namecheap DNS records point to `188.245.16.94`, install the production Caddyfile:

```sh
scp -i ~/.ssh/id_ed25519_hetzner -o IdentitiesOnly=yes -o BatchMode=yes infra/Caddyfile root@188.245.16.94:/etc/caddy/Caddyfile
ssh -i ~/.ssh/id_ed25519_hetzner -o IdentitiesOnly=yes -o BatchMode=yes root@188.245.16.94 'caddy validate --config /etc/caddy/Caddyfile && systemctl reload caddy'
```

DNS in Namecheap Advanced DNS:

| Type | Host | Value |
| --- | --- | --- |
| A Record | `@` | `188.245.16.94` |
| A Record | `s` | `188.245.16.94` |
| CNAME Record | `www` | `yigit.dev` |

Replace the old GitHub Pages A records and the `www` CNAME pointing at `yigitcukuren.github.io`. Do not leave conflicting records. Caddy obtains and renews HTTPS certificates after DNS resolves and ports 80/443 reach the server.

## Data and recovery

Wallos stores its database in `/srv/wallos/db` and uploaded logos in `/srv/wallos/logos`. Back up both directories together. To restore on a replacement server, install Docker and Caddy, copy the homepage, Caddyfile, Compose file, and these two directories, then run `docker compose up -d` in `/srv/wallos`.

To update Wallos intentionally, change the pinned image tag in `infra/wallos/compose.yaml`, back up the two data directories, deploy the Compose file, and run `docker compose pull && docker compose up -d` in `/srv/wallos`.
