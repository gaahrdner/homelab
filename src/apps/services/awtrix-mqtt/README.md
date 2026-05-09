# AWTRIX MQTT

This app deploys a local MQTT broker for AWTRIX devices plus a Prometheus exporter that subscribes to AWTRIX stats topics.

## What It Provides

- `Mosquitto` broker exposed on the LAN at `mqtt-awtrix.internal:1883`
- `mqtt-exporter` scraped by Prometheus for AWTRIX device stats
- Longhorn-backed persistence for retained messages and sessions
- MQTT authentication via 1Password

## 1Password Setup

Create an item in the `kubernetes` vault named `awtrix-mqtt-credentials` with:

- `username`
- `password`

The OnePassword operator syncs that item into the `awtrix` namespace.

## AWTRIX Device Setup

In the AWTRIX web UI:

- MQTT server: `mqtt-awtrix.internal`
- MQTT port: `1883`
- MQTT username/password: from `awtrix-mqtt-credentials`
- MQTT base topic: `awtrix/office`

The exporter is configured to scrape AWTRIX stats topics under:

- `awtrix/+/stats`
- `awtrix/+/stats/#`

## MQTT Topics

AWTRIX updates:

- Custom app: `[PREFIX]/custom/[appname]`
- Notification: `[PREFIX]/notify`
- Dismiss held notification: `[PREFIX]/notify/dismiss`

AWTRIX stats:

- `[PREFIX]/stats`
- `[PREFIX]/stats/effects`
- `[PREFIX]/stats/transitions`
- `[PREFIX]/stats/loop`

## Example Publish Commands

Replace `awtrix/office` with your configured device prefix.

```bash
mosquitto_pub -h mqtt-awtrix.internal -p 1883 \
  -u '<username>' -P '<password>' \
  -t 'awtrix/office/custom/k8s' \
  -m '{"text":"norns OK","color":[0,255,0],"duration":10}'
```

```bash
mosquitto_pub -h mqtt-awtrix.internal -p 1883 \
  -u '<username>' -P '<password>' \
  -t 'awtrix/office/notify' \
  -m '{"text":"Longhorn healthy","color":[255,255,255],"background":[0,64,128]}'
```
