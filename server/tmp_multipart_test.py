import http.client

boundary = 'TESTBOUNDARY'
body = b'--' + boundary.encode() + b'\r\n'
body += b'Content-Disposition: form-data; name="email"\r\n\r\n'
body += b'test@example.com\r\n'
body += b'--' + boundary.encode() + b'--\r\n'

conn = http.client.HTTPConnection('127.0.0.1', 5000, timeout=10)
conn.request(
    'POST',
    '/api/accounts/register-seller',
    body=body,
    headers={'Content-Type': f'multipart/form-data; boundary={boundary}'},
)
r = conn.getresponse()
print('STATUS', r.status, r.reason)
print(r.read(500).decode('utf-8', errors='replace'))
conn.close()
