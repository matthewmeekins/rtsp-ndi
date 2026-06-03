# rtsp-ndi

Bridge an RTSP stream to an NDI source on your local network.

This was built mostly using Claude. Use at your own risk

## Install

### macOS (recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/matthewmeekins/rtsp-ndi/main/install.sh | bash
```

Requires [Homebrew](https://brew.sh). The script handles FFmpeg, Python, and the package automatically.

### Other platforms

```bash
pip install rtsp-ndi
```

Also requires **FFmpeg** on your `PATH`:
- Windows: https://ffmpeg.org/download.html
- Linux: `sudo apt install ffmpeg`

## Usage

```bash
rtsp-to-ndi --url rtsp://YOUR_CAMERA_IP/stream --name "Camera 1"
```

The source will appear in any NDI-aware application (OBS, vMix, NDI Monitor) on your local network.

## Options

```
--url      RTSP source URL (required)
--name     NDI source name shown on the network (default: "RTSP Source")
--latency  low or normal (default: low)
```

## Notes

- The NDI runtime is bundled automatically via the `ndi-python` dependency — no manual SDK download needed.
- To use a custom NDI SDK install, set `NDI_SDK_LIB=/path/to/libndi`.
