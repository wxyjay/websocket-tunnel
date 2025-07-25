#!/usr/bin/python3
import socket, threading, select, sys, getopt, time

# Default Listen
LISTENING_ADDR = '0.0.0.0'
LISTENING_PORT = 8098 # Default port if no argument is given

# Pass
PASS = ''

# CONST
BUFLEN = 4096 * 4
TIMEOUT = 60
DEFAULT_HOST = '127.0.0.1:22'
RESPONSE = 'HTTP/1.1 101 Switching Protocols\r\n\r\nContent-Length: 104857600000\r\n\r\n'

# --- The rest of the script remains the same ---
# (Server class, ConnectionHandler class, etc. are unchanged)
class Server(threading.Thread):
    def __init__(self, host, port):
        threading.Thread.__init__(self)
        self.running = False
        self.host = host
        self.port = port
        self.threads = []
        self.threadsLock = threading.Lock()
        self.logLock = threading.Lock()

    def run(self):
        self.soc = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.soc.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.soc.settimeout(2)
        intport = int(self.port)
        self.soc.bind((self.host, intport))
        self.soc.listen(0)
        self.running = True

        try:
            while self.running:
                try:
                    c, addr = self.soc.accept()
                    c.setblocking(1)
                except socket.timeout:
                    continue

                conn = ConnectionHandler(c, self, addr)
                conn.start()
                self.addConn(conn)
        finally:
            self.running = False
            self.soc.close()

    def printLog(self, log):
        self.logLock.acquire()
        print(log)
        self.logLock.release()

    def addConn(self, conn):
        try:
            self.threadsLock.acquire()
            if self.running:
                self.threads.append(conn)
        finally:
            self.threadsLock.release()

    def removeConn(self, conn):
        try:
            self.threadsLock.acquire()
            self.threads.remove(conn)
        finally:
            self.threadsLock.release()

    def close(self):
        try:
            self.running = False
            self.threadsLock.acquire()

            threads = list(self.threads)
            for c in threads:
                c.close()
        finally:
            self.threadsLock.release()


class ConnectionHandler(threading.Thread):
    def __init__(self, socClient, server, addr):
        threading.Thread.__init__(self)
        self.clientClosed = False
        self.targetClosed = True
        self.client = socClient
        self.client_buffer = b''
        self.server = server
        self.log = 'Connection: ' + str(addr)

    def close(self):
        try:
            if not self.clientClosed:
                self.client.shutdown(socket.SHUT_RDWR)
                self.client.close()
        except:
            pass
        finally:
            self.clientClosed = True

        try:
            if not self.targetClosed:
                self.target.shutdown(socket.SHUT_RDWR)
                self.target.close()
        except:
            pass
        finally:
            self.targetClosed = True

    def run(self):
        try:
            self.client_buffer = self.client.recv(BUFLEN)

            hostPort = self.findHeader(self.client_buffer, b'X-Real-Host')

            if hostPort == b'':
                hostPort = DEFAULT_HOST.encode('utf-8')

            split = self.findHeader(self.client_buffer, b'X-Split')

            if split != b'':
                self.client.recv(BUFLEN)

            if hostPort != b'':
                passwd = self.findHeader(self.client_buffer, b'X-Pass')

                if len(PASS) != 0 and passwd == PASS.encode('utf-8'):
                    self.method_CONNECT(hostPort)
                elif len(PASS) != 0 and passwd != PASS.encode('utf-8'):
                    self.client.send(b'HTTP/1.1 400 WrongPass!\r\n\r\n')
                elif hostPort.startswith(b'127.0.0.1') or hostPort.startswith(b'localhost'):
                    self.method_CONNECT(hostPort)
                else:
                    self.client.send(b'HTTP/1.1 403 Forbidden!\r\n\r\n')
            else:
                print('- No X-Real-Host!')
                self.client.send(b'HTTP/1.1 400 NoXRealHost!\r\n\r\n')

        except Exception as e:
            self.log += ' - error: ' + str(e)
            self.server.printLog(self.log)
        finally:
            self.close()
            self.server.removeConn(self)

    def findHeader(self, head, header):
        aux = head.find(header + b': ')

        if aux == -1:
            return b''

        aux = head.find(b':', aux)
        head = head[aux+2:]
        aux = head.find(b'\r\n')

        if aux == -1:
            return b''

        return head[:aux];

    def connect_target(self, host):
        i = host.find(b':')
        if i != -1:
            port = int(host[i+1:])
            host = host[:i]
        else:
            if self.method=='CONNECT':
                port = 443
            else:
                # Use the global LISTENING_PORT for consistency if needed, though this context is for the target port
                port = 80

        (soc_family, soc_type, proto, _, address) = socket.getaddrinfo(host.decode('utf-8'), port)[0]

        self.target = socket.socket(soc_family, soc_type, proto)
        self.targetClosed = False
        self.target.connect(address)

    def method_CONNECT(self, path):
        self.log += ' - CONNECT ' + path.decode('utf-8')

        self.connect_target(path)
        self.client.sendall(RESPONSE.encode('utf-8'))
        self.client_buffer = b''

        self.server.printLog(self.log)
        self.doCONNECT()

    def doCONNECT(self):
        socs = [self.client, self.target]
        count = 0
        error = False
        while True:
            count += 1
            (recv, _, err) = select.select(socs, [], socs, 3)
            if err:
                error = True
            if recv:
                for in_ in recv:
                    try:
                        data = in_.recv(BUFLEN)
                        if data:
                            if in_ is self.target:
                                self.client.send(data)
                            else:
                                while data:
                                    byte = self.target.send(data)
                                    data = data[byte:]

                            count = 0
                        else:
                            break
                    except:
                        error = True
                        break
            if count == TIMEOUT:
                error = True
            if error:
                break

if __name__ == '__main__':
    # If a command-line argument is provided, use it as the port
    if len(sys.argv) > 1:
        try:
            port_arg = int(sys.argv[1])
            if 1 <= port_arg <= 65535:
                LISTENING_PORT = port_arg
            else:
                print(f"Warning: Invalid port '{sys.argv[1]}'. Using default {LISTENING_PORT}.")
        except ValueError:
            print(f"Warning: Invalid port argument '{sys.argv[1]}'. Using default {LISTENING_PORT}.")

    print("\n:------- SSH over Websocket Tunnel by Lunch-------:\n")
    print(f"Listening addr: {LISTENING_ADDR}")
    print(f"Listening port: {LISTENING_PORT}\n")
    print(":-------------------------:\n")
    
    server = Server(LISTENING_ADDR, LISTENING_PORT)
    server.start()
    
    try:
        while True:
            time.sleep(2)
    except KeyboardInterrupt:
        print('Stopping...')
        server.close()
