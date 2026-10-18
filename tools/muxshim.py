"""usbmuxd shim for WSL: forwards to Apple's usbmuxd on Windows, but answers
Listen requests locally, because Apple's service stops responding to other
requests while a Listen connection is open."""
import os, plistlib, socket, struct, sys, threading

UPSTREAM = (sys.argv[1], int(sys.argv[2]))
SOCK_PATH = "/var/run/usbmuxd"


def recv_exact(s, n):
    buf = b""
    while len(buf) < n:
        chunk = s.recv(n - len(buf))
        if not chunk:
            raise ConnectionError("closed")
        buf += chunk
    return buf


def read_packet(s):
    hdr = recv_exact(s, 16)
    length, version, msg, tag = struct.unpack("<IIII", hdr)
    return hdr, recv_exact(s, length - 16), version, msg, tag


def packet(obj, tag):
    body = plistlib.dumps(obj)
    return struct.pack("<IIII", 16 + len(body), 1, 8, tag) + body


def upstream_devices():
    s = socket.create_connection(UPSTREAM, timeout=10)
    try:
        s.sendall(packet({"MessageType": "ListDevices", "ClientVersionString": "muxshim", "ProgName": "muxshim"}, 1))
        _, body, *_ = read_packet(s)
        return plistlib.loads(body).get("DeviceList", [])
    finally:
        s.close()


def pipe(src, dst):
    try:
        while True:
            data = src.recv(65536)
            if not data:
                break
            dst.sendall(data)
    except OSError:
        pass
    finally:
        for s in (src, dst):
            try:
                s.shutdown(socket.SHUT_RDWR)
            except OSError:
                pass


def handle(client):
    try:
        hdr, body, version, msg, tag = read_packet(client)
        req = plistlib.loads(body) if msg == 8 else {}
        if req.get("MessageType") == "Listen":
            client.sendall(packet({"MessageType": "Result", "Number": 0}, tag))
            for dev in upstream_devices():
                client.sendall(packet({"MessageType": "Attached", "DeviceID": dev["DeviceID"],
                                       "Properties": dev["Properties"]}, 0))
            while client.recv(4096):
                pass
            return
        up = socket.create_connection(UPSTREAM, timeout=10)
        up.settimeout(None)
        up.sendall(hdr + body)
        threading.Thread(target=pipe, args=(up, client), daemon=True).start()
        pipe(client, up)
    except (OSError, ConnectionError, plistlib.InvalidFileException):
        pass
    finally:
        client.close()


def main():
    try:
        os.unlink(SOCK_PATH)
    except FileNotFoundError:
        pass
    srv = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    srv.bind(SOCK_PATH)
    os.chmod(SOCK_PATH, 0o666)
    srv.listen(64)
    print(f"muxshim: {SOCK_PATH} -> {UPSTREAM[0]}:{UPSTREAM[1]}", flush=True)
    while True:
        client, _ = srv.accept()
        threading.Thread(target=handle, args=(client,), daemon=True).start()


if __name__ == "__main__":
    main()
