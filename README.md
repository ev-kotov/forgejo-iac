# forgejo-iac

A rootless IaC of [forgejo](https://forgejo.org/) using [Podman](https://github.com/podman-container-tools/podman) (version earlier then 5).

The project uses `.container` files instead of grouping via `.pod`, as pod generation using `.pod` is not supported in Podman 4.9.x - resulting in an `unsupported key 'Pod' in group 'Container'` error (confirmed in issue [#21371](https://github.com/podman-container-tools/podman/issues/21371)). Full support for `.pod` was added in Podman 5.0.0.

## Requirments

- [init-iac](https://github.com/ev-kotov/init-iac)

## Run

```bash
chmod +x deploy.sh
sh deploy.sh
```

After deploy change variable:

```forgejo.env
FORGEJO__security__INSTALL_LOCK=false > FORGEJO__security__INSTALL_LOCK=true
```

Reload and restart:

```bash
systemctl --user daemon-reload
systemctl --user restart forgejo-server.service
```

Create admin:

```bash
podman exec -u git -it forgejo-server forgejo admin user create \
  --admin \
  --username your_login \
  --password "your_password" \
  --email "you_mail" \
  --must-change-password=false
```

Go to web and autorized.

## Update

Change iac and execute:

```bash
sh deploy.sh
```
