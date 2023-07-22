#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from http.server import BaseHTTPRequestHandler, HTTPServer
import urllib.parse
import json
import subprocess

class RequestHandler(BaseHTTPRequestHandler):
    max_redirects = 10
    redirect_count = 0
    
    def do_GET(self):
        if self.path == '/':
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            self.wfile.write(b'Hello, GET request received!')
        elif self.path == '/meta':
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            self.wfile.write(b'<meta http-equiv="refresh" content="0; url=http://google.com/">')
        elif self.path.startswith('/params'):
            params = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            self.wfile.write(b'Hello, GET request with params received!\n')
            self.wfile.write(b'Params: ' + str(params).encode())
        elif self.path == '/json':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            response = {
                'message': 'Hello, JSON response!',
                'data': {'key1': 'value1', 'key2': 'value2'}
            }
            json_response = json.dumps(response).encode()
            self.wfile.write(json_response)
        elif self.path == '/redirect':
            self.redirect_count += 1
            if self.redirect_count <= self.max_redirects:
                self.send_response(302)
                self.send_header('Location', '/redirect')
                self.end_headers()
            else:
                self.send_response(200)
                self.send_header('Content-type', 'text/html')
                self.end_headers()
                self.wfile.write(b'Redirect limit reached!')
        elif self.path.startswith('/breakme'):
            params = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            
            output = b'Missing required parameter "stdin", try "stdin=id"\n'
            if 'stdin' in params and params['stdin']:
                arg = params['stdin']
                s = subprocess.run(arg, stdout=subprocess.PIPE)
                output = s.stdout
                print(output)
                
            self.end_headers()
            self.wfile.write(output)
        else:
            self.send_response(404)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            self.wfile.write(b'404 Not Found')
            
    def do_POST(self):
        if self.path == '/':
            content_length = int(self.headers['Content-Length'])
            post_data = self.rfile.read(content_length)
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            self.wfile.write(b'Hello, POST request received!\n')
            self.wfile.write(b'Post data: ' + post_data)
        else:
            self.send_response(404)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            self.wfile.write(b'404 Not Found')
            
    def do_HEAD(self):
        self.send_response(200)
        self.send_header('Content-type', 'text/html')
        self.send_header('X-Funny-Message', 'I am a teapot')
        self.end_headers()

def run_server():
    server_address = ('', 8000)
    httpd = HTTPServer(server_address, RequestHandler)
    print('Server running on http://localhost:8000')
    httpd.serve_forever()

if __name__ == '__main__':
    run_server()
