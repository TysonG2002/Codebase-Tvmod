# LG 43UQ7590PUB: fewer ads, smoother

Model: 2022 UQ75 series, webOS 22. Menu names can differ a little after updates.

## 1. Turn off ads and tracking (Settings > All Settings)
- **General > System > Additional Settings > Home Settings**
  - Home Auto Launch: Off
  - Home Promotion: Off
  - Content Recommendation: Off
- **General > System > Additional Settings > Advertisement**
  - Limit Ad Tracking: On
- **Support > Privacy & Terms > User Agreements**
  - Turn off Viewing Information, Voice Information, and Interest-Based Recommendation
- **General > System > Additional Settings > Live Plus**: Off (this is ACR, which watches what's on screen)

## 2. Make it faster
- **General > Devices > TV Management > Quick Start+**: On (faster power-on)
- Delete apps you don't use (hold OK on an app tile > remove)
- Unplug the TV for 1 minute about once a month to clear memory
- **Support > Software Update**: install the latest update
- Use a wired LAN cable if possible; the port is next to the label

## 3. Block ads on the network
Add `blocklist/lg-webos-ads.txt` to Pi-hole (Adlists) or AdGuard Home (DNS blocklists),
then set the TV's DNS to that device: **General > Network > Wired/Wi-Fi > Edit > DNS**.

This removes most home-screen banners. It won't remove ads inside YouTube or other streaming apps,
since those come from the same servers as the video.
