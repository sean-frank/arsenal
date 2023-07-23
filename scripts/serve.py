#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
from http.server import BaseHTTPRequestHandler, HTTPServer

class RequestHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/':
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            self.wfile.write(b'Hello World! Successfully serving from a local server!')
        else:
            # wildcard path, this is for testing purposes only
            # serves the contents of the current directory
            
            # get directory of repository
            repo_dir = os.path.dirname(os.path.dirname(os.path.realpath(__file__)))
            
            # get path of file to serve
            path = self.path[1:]
            
            # get full path of file to serve
            full_path = os.path.join(repo_dir, path)
            if os.path.isfile(full_path):
                # serve file, it most likely is a text file
                self.send_response(200)
                self.send_header('Content-type', 'text/plain')
                self.end_headers()
                with open(full_path, 'rb') as f:
                    self.wfile.write(f.read())
            else:
                # file not found
                self.send_response(404)
                self.send_header('Content-type', 'text/html')
                self.end_headers()
                self.wfile.write(b'File not found: "' + path.encode() + b'"\n')

HOST = ''
PORT = 8000

def run():
    server_address = (HOST, PORT)
    httpd = HTTPServer(server_address, RequestHandler)
    print(f'Server running on http://{HOST}:{PORT}')
    httpd.serve_forever()

if __name__ == '__main__':
    run()
