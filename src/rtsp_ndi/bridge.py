#!/usr/bin/env python3
"""
RTSP to NDI bridge.
Decodes an RTSP stream via FFmpeg (PyAV) and re-sends it as an NDI source.

Usage:
    python rtsp_to_ndi.py --url rtsp://192.168.1.100/stream --name "Camera 1"
"""

import argparse
import ctypes
import signal
import sys
import time

import av
import numpy as np

from rtsp_ndi import ndi_ctypes as ndi


def run(rtsp_url: str, ndi_name: str, latency: str = "low") -> None:
    if not ndi.initialize():
        print("ERROR: Could not initialize NDI.")
        sys.exit(1)

    sender = ndi.send_create(ndi_name, clock_video=False)
    print(f"NDI source '{ndi_name}' created.")

    options = {
        "rtsp_transport": "tcp",
        "fflags": "nobuffer",
        "flags": "low_delay",
        "max_delay": "0",
    }
    if latency == "low":
        options["analyzeduration"] = "0"
        options["probesize"] = "32"

    print(f"Opening RTSP stream: {rtsp_url}")
    try:
        container = av.open(rtsp_url, options=options, timeout=10.0)
    except Exception as e:
        print(f"ERROR: Could not open RTSP stream: {e}")
        ndi.send_destroy(sender)
        ndi.destroy()
        sys.exit(1)

    video_stream = next((s for s in container.streams if s.type == "video"), None)
    if not video_stream:
        print("ERROR: No video stream found.")
        container.close()
        ndi.send_destroy(sender)
        ndi.destroy()
        sys.exit(1)

    frame_rate = float(video_stream.average_rate or 30)
    print(f"Stream: {video_stream.width}x{video_stream.height} @ {frame_rate:.2f} fps")

    running = True

    def shutdown(sig, frame):
        nonlocal running
        print("\nShutting down...")
        running = False

    signal.signal(signal.SIGINT, shutdown)
    signal.signal(signal.SIGTERM, shutdown)

    frame_count = 0
    start_time = time.monotonic()

    try:
        for packet in container.demux(video_stream):
            if not running:
                break
            for av_frame in packet.decode():
                if not running:
                    break

                # UYVY422 is NDI's native packed format — no extra conversion
                raw = av_frame.to_ndarray(format="uyvy422")
                if not raw.flags["C_CONTIGUOUS"]:
                    raw = np.ascontiguousarray(raw)

                ndi_frame = ndi.VideoFrameV2()
                ndi_frame.xres                 = av_frame.width
                ndi_frame.yres                 = av_frame.height
                ndi_frame.FourCC               = ndi.FOURCC_UYVY
                ndi_frame.frame_rate_N         = int(frame_rate * 1000)
                ndi_frame.frame_rate_D         = 1000
                ndi_frame.picture_aspect_ratio = av_frame.width / av_frame.height
                ndi_frame.frame_format_type    = ndi.FRAME_FORMAT_PROGRESSIVE
                ndi_frame.timecode             = 0x8000000000000000  # NDI_SEND_TIMECODE_SYNTHESIZE
                ndi_frame.p_data               = raw.ctypes.data_as(ctypes.c_void_p)
                ndi_frame.line_stride_or_size  = av_frame.width * 2  # UYVY = 2 bytes/pixel

                ndi.send_video_v2(sender, ndi_frame)
                frame_count += 1

                if frame_count % 300 == 0:
                    elapsed = time.monotonic() - start_time
                    print(f"  {frame_count} frames sent ({frame_count/elapsed:.1f} fps avg)")

    except Exception as e:
        print(f"Stream error: {e}")
    finally:
        container.close()
        ndi.send_destroy(sender)
        ndi.destroy()
        print(f"Done. {frame_count} frames sent.")


def main():
    parser = argparse.ArgumentParser(description="Bridge an RTSP stream to NDI.")
    parser.add_argument("--url",  required=True, help="RTSP source URL")
    parser.add_argument("--name", default="RTSP Source", help="NDI source name")
    parser.add_argument("--latency", choices=["low", "normal"], default="low")
    args = parser.parse_args()
    run(args.url, args.name, args.latency)


if __name__ == "__main__":
    main()
