# Changelog

All notable changes to this project will be documented in this file.

## [2025.11.08]

### Added
- Gateway API v1.2.1 CRDs for modern ingress/routing
- Cilium v1.18.3 as CNI with kube-proxy replacement
- Hubble observability (relay + UI)
- Cilium L2 announcements for LoadBalancer IP advertisement via ARP
- LoadBalancer IP pool (192.168.0.200-253) using CiliumLoadBalancerIPPool
- `mise run setup-networking` - Complete networking setup with CNI transition
- `mise run setup-loadbalancer` - Configure LoadBalancer IP pool
- CLAUDE.md with working principles and critical networking setup guidance
- Talos Linux v1.11.5 cluster configuration
- Three control plane nodes (urd, verdandi, skuld) with pod scheduling enabled
- Custom Talos image with system extensions (gvisor, i915, intel-ucode, iscsi-tools, util-linux-tools)
- Mise task runner for cluster management
- Secure Boot support
- High pod density configuration (300 max pods per node)
