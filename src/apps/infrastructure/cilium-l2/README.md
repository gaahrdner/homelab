# Cilium L2 Announcements

LoadBalancer IP address pool using Cilium's L2 announcement feature.

## Installation

Managed by ArgoCD via the root application.

## Configuration

- **IP Range**: 192.168.0.200-253 (54 addresses)
- **Interface**: Uses Cilium's L2 announcement to advertise LoadBalancer IPs via ARP

## Dependencies

- Cilium CNI (bootstrap/cilium)
- CiliumLoadBalancerIPPool CRD (provided by Cilium)

## How It Works

When a Service with `type: LoadBalancer` is created, Cilium assigns an IP from this pool and announces it on the local network using ARP, making it reachable without an external load balancer.
