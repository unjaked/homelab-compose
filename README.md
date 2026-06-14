# Docker Composes for Homelab

## Media

[Jellyfin](https://jellyfin.org/) front-end *(with several plugins)* and [*arr](https://wiki.servarr.com/) back-end. 

Self-hosted media system for streaming movies and TV shows.

**Full Stack:** Jellyfin, Seerr, Radarr, Sonarr, Bazarr, Prowlarr, Decyparr, Byparr, Cleanuparr 

### Stack Flow
```
Jellyfin
   ↓ user requests media
Seerr
   ↓ forwards request to radarr/sonarr
Radarr/Sonarr
   ↓ asks Prowlarr to search
Prowlarr
   ↓ searches indexes for candidate torrents
Radarr/Sonarr
   ↓ chooses best torrent and forwards for download
Decypharr
   ↓ emulates qBittorrent API and forwards to debrid service
Torbox (debrid)
   ↓ torrents the file from the cloud (or immediately serves file if already cached)
Decypharr mount/output
   ↓ imports to radarr/sonarr
Radarr/Sonarr
   ↓ puts content in Jellyfin media folder
Jellyfin
   ↳ delivers content to user
```

#### Additionally:

* Byparr is used to get past Cloudflare checks and challenges for certain indexers. Does not always work.
* Cleanuparr manages corrupt, incomplete, or stuck download files and prevents potenitally malicious ones.

The cloud/Debrid download layer of **Decypharr → Torbox → Decypharr** is used over a self-hosted Torrent Client or Usenet Client for a few reasons:

* Debrid clients like Torbox will cache/seed torrents requested by other users for a number of days. If the torrent I request is already cached, then the torrent's content can be delivered immediately at FULL internet speed instead of at the speed of seeders. This is what allows for torrent files to be streamed.

* No seeding is done on my end, only on Torbox's cloud servers, meaning my IP remains protected and others or my ISP cannot see what content I am torrenting.

* Since everything is streamed from the cloud, no space is being used on my harddisks. Thousands of movies taking up no space.

* Cheapest option. Alternative would be torrenting myself which would be slow, require lots of physical storage, and a VPN subscription. Usenets require subscription to get access to and allow for very fast download speeds, but also require lots of physical storage (no streaming).
