# ProxMeTrue

English-maintained fork of `sing-box-yg`, published as `anyagixx/proxmetrue`.

## Fork Status

- Upstream project: [`yonggekkk/sing-box-yg`](https://github.com/yonggekkk/sing-box-yg)
- Fork repository: [`anyagixx/proxmetrue`](https://github.com/anyagixx/proxmetrue)
- Scope of this fork:
  - full English localization
  - cleanup of UI, docs, and operational messages
  - self-hosted install and update URLs that point to this fork

## What This Product Is

`ProxMeTrue` is an infrastructure automation toolkit for deploying and maintaining `sing-box` proxy/VPN setups.

It includes:

- a VPS-oriented multi-protocol installer
- a Serv00/Hostuno deployment flow
- keepalive and restart helpers
- GitHub Actions and Worker-based automation
- web endpoints for lightweight remote operations

## Included Products

# # # I. `sing-box-yg` One-Click Five-Protocol Script for VPS
# # # II. `Serv00/Hostuno-sb-yg` One-Click Three-Protocol Script for Serv00/Hostuno

# # # Note: all shared nodes and subscription files in this project are generated locally. No third-party node converters or hosted subscription services are used.

# # # Communication platform: [Yongge's blog](https://ygkkk.blogspot.com), [Yongge's YouTube channel](https://www.youtube.com/@ygkkk), [Yongge's Telegram group](https://t.me/+jZHc6-A-1QQ5ZGVl), [Yongge's Telegram channel](https://t.me/+DkC9ZZUgEFQzMTZl)

----------------------------------------------------------------
# # # # Recommended alternative: if you want a more minimal and lightweight multi-protocol setup, see the [ArgoSBX project](https://github.com/yonggekkk/argosbx)

--------------------------------------------------------------

# # # I. `sing-box-yg` Beginner-Friendly One-Click Five-Protocol Script for VPS

* Supports five of the most popular protocols: Vless-reality-vision, Vmess-ws (tls) /Argo, Hysteria-2, Tuic-v5, Anytls

* Supports pure IPv6, pure IPv4, and dual-stack VPS setups; supports both AMD64 and ARM; Alpine is supported, but the latest Ubuntu release is recommended

* Beginner mode: no domain or certificate is required; in the simplest flow you can finish installation with three Enter presses and then copy or scan the generated node configuration

# # # # For instructions and precautions, please refer to [Yongge's blog description and Sing-box video tutorial] (https://ygkkk.blogspot.com/2023/10/sing-box-yg.html)

Video Tutorials:

[🥇Build Agent 9 Top Problem Leaderboard: No. 4 99% of the entire network is misled! # 1 Everybody's been tossed!] (https://youtu.be/pJwJBqBkcfw)

[🥇2025 agency agreement "pull to ramp" comprehensive ranking] (https://youtu.be/IoFtykGXDao)

[Sing-box one-click script (1): unified config for SFA/SFI/SFW clients, Argo tunnels, dual certificate switching, and domain-based routing](https://youtu.be/QwTapeVPeB0)

[Sing-box one-click script (2): pure IPv6 VPS deployment, CDN preferred-IP settings, and full client setup across platforms](https://youtu.be/kmTgj1DundU)

[Sing-box one-click script (3): self-hosted GitLab private subscription sync, Warp routing for ChatGPT, and subscription support for the SFW desktop client](https://youtu.be/by7C2HU6-fU)

[Sing-box one-click script (4): advanced CDN preferred-IP options for the VMess protocol](https://youtu.be/Qfm8DbLeb6w)

[Sing-box one-click script (5): integrated Oblivion Warp free VPN support, plus switchable local Warp and Psiphon routing across 30 country IP options](https://youtu.be/5Y6NPsYPws0)

[Sing-box major update (6): adds AnyTLS and automatic local-IP subscription updates for Clash/Mihomo, Sing-box, and aggregated nodes](https://youtu.be/LF0-n6-Z6kI)

# # # VPS one-click installer. Shortcut: `sb`

```
bash <(wget -qO- https://raw.githubusercontent.com/anyagixx/proxmetrue/main/sb.sh)
```
or
```
bash <(curl -Ls https://raw.githubusercontent.com/anyagixx/proxmetrue/main/sb.sh)
```

# # # Sing-box-yg script interface preview diagram (Note: relevant parameters are free to fill in, only for crowd viewing)

![1d5425c093618313888fe41a55f493f](https://github.com/user-attachments/assets/2b4b04a6-2de4-499a-afa1-ed78bccc50a8)

-----------------------------------------------------

# # # II. Serv00/Hostuno One-Click Three-Protocol Script

* Free Serv00 accounts may still face account-blocking risk when used for proxy workloads. The paid Hostuno service is not affected in the same way.

* DO not mix with other Serv00 scripts!!!

* Includes related functionality from [King eooce](https://github.com/eooce/Sing-box/blob/test/sb_00.sh) and [frankiejun](https://github.com/frankiejun/serv00-play/blob/main/start.sh), with one-click support for three protocols: vless-reality, vmess-ws(argo), and hysteria2

* Adds default support for Cloudflare `vless/trojan` `proxyip` handling in reality mode, plus preferred reverse-proxy IP support for non-standard ports

* Provides an aggregated share list with up to 22 nodes: three IPs for each of the three protocols, plus full Argo coverage across 13 ports with resilient preferred IPs included

# # # # For instructions and precautions, please see [Yongge's blog description and Serv00 video tutorial] (https://ygkkk.blogspot.com/2025/01/serv00.html)

Video Tutorials:

[Serv00 final tutorial (1): custom installation with three IPs, support for `proxyip` and reverse-proxy IPs, Argo temporary/fixed tunnels, CDN origin routing, and five-node Sing-box/Clash subscription output](https://youtu.be/2VF9D6z2z7w)

[Serv00 final tutorial (2): deploy and keep everything alive without logging into SSH again, with reusable GitHub/VPS/router workflows for multi-platform, multi-account setups](https://youtu.be/rYeX1iU_iZ0)

[Serv00 final tutorial (3): generate a multifunction web page for keepalive, restart, port reset, and subscription viewing, with optional automated keepalive via GitHub or Workers](https://youtu.be/9uCfFNnjNc0)

[Serv00 final tutorial (4): switch between temporary and fixed Argo tunnels with real-time node updates; fully compatible with the paid Hostuno service](https://youtu.be/XN6_vpz1NhE)

[Serv00 final tutorial (5): major updates for GitHub, VPS, and router deployment scripts, including multifunction web pages and a choice between cron-based or external keepalive](https://youtu.be/tKaBdbU4G4s)

# # # Serv00/Hostuno-sb-yg Installer

* Argo highly customizable: can reset temporary tunnel; can continue to use last fixed tunnel; can also change fixed tunnel domain name or token

```
bash <(curl -Ls https://raw.githubusercontent.com/anyagixx/proxmetrue/main/serv00.sh)
```

# # # # Serv00/Hostuno-sb-yg UI Preview, SSH installation flow for scenario 1 only
![a6b776a094566ab14e88fdcd70ba9e9](https://github.com/user-attachments/assets/90a918ed-aec7-4a1f-8159-97f3acfd0092)


-----------------------------------------------------
# # # Thanks for the support! WeChat: `ygkkk`
![41440820a366deeb8109db5610313a1](https://github.com/user-attachments/assets/5cd2d891-ae54-4397-8211-ac4c6d1099c9)

---------------------------------------
# # # Thank you for the star in the upper right corner🌟
[![Stargazers over time](https://starchart.cc/anyagixx/proxmetrue.svg)](https://starchart.cc/anyagixx/proxmetrue)

---------------------------------------
# # # # Note: this project is assembled from GitHub community resources together with ChatGPT-assisted integration
