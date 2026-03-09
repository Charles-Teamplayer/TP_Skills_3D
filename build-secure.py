#!/usr/bin/env python3
"""MAGI Secure Build — AES-256-GCM 클라이언트 암호화 빌드"""
import os, sys, json, base64, hashlib, secrets

def encrypt_aes_gcm(plaintext: bytes, password: str) -> dict:
    """AES-256-GCM encrypt using pure Python (for build step only).
    Browser decrypts using Web Crypto API."""
    from cryptography.hazmat.primitives.ciphers.aead import AESGCM
    from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
    from cryptography.hazmat.primitives import hashes

    salt = secrets.token_bytes(16)
    iv = secrets.token_bytes(12)

    kdf = PBKDF2HMAC(algorithm=hashes.SHA256(), length=32, salt=salt, iterations=100_000)
    key = kdf.derive(password.encode('utf-8'))

    aesgcm = AESGCM(key)
    ct = aesgcm.encrypt(iv, plaintext, None)

    return {
        'salt': base64.b64encode(salt).decode(),
        'iv': base64.b64encode(iv).decode(),
        'ct': base64.b64encode(ct).decode()
    }

def encrypt_aes_gcm_fallback(plaintext: bytes, password: str) -> dict:
    """Fallback using openssl via subprocess"""
    import subprocess, tempfile

    salt = secrets.token_bytes(16)
    iv = secrets.token_bytes(12)

    # Derive key with PBKDF2
    dk = hashlib.pbkdf2_hmac('sha256', password.encode(), salt, 100_000, dklen=32)

    # Write plaintext to temp file
    with tempfile.NamedTemporaryFile(delete=False, suffix='.bin') as f:
        f.write(plaintext)
        pt_path = f.name

    ct_path = pt_path + '.enc'
    key_hex = dk.hex()
    iv_hex = iv.hex()

    try:
        result = subprocess.run([
            'openssl', 'enc', '-aes-256-gcm',
            '-in', pt_path, '-out', ct_path,
            '-K', key_hex, '-iv', iv_hex,
            '-nosalt'
        ], capture_output=True, text=True)

        if result.returncode != 0:
            raise RuntimeError(f"openssl failed: {result.stderr}")

        with open(ct_path, 'rb') as f:
            ct = f.read()

        return {
            'salt': base64.b64encode(salt).decode(),
            'iv': base64.b64encode(iv).decode(),
            'ct': base64.b64encode(ct).decode()
        }
    finally:
        os.unlink(pt_path)
        if os.path.exists(ct_path):
            os.unlink(ct_path)

GATE_TEMPLATE = r'''<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>MAGI SYSTEM — AUTHENTICATION REQUIRED</title>
<style>
@import url('https://fonts.googleapis.com/css2?family=Share+Tech+Mono&family=Orbitron:wght@400;600;700;900&display=swap');
*{margin:0;padding:0;box-sizing:border-box}
body{background:#020a08;color:rgba(0,255,200,0.7);font-family:'Share Tech Mono',monospace;
  display:flex;align-items:center;justify-content:center;min-height:100vh;overflow:hidden}
body::after{content:'';position:fixed;top:0;left:0;width:100%;height:100%;pointer-events:none;z-index:100;
  background:repeating-linear-gradient(0deg,transparent,transparent 2px,rgba(0,0,0,0.03) 2px,rgba(0,0,0,0.03) 4px)}
body::before{content:'';position:fixed;top:0;left:0;width:100%;height:100%;pointer-events:none;z-index:99;
  background:radial-gradient(ellipse at center,transparent 50%,rgba(0,0,0,0.4) 100%)}

.gate{width:420px;max-width:90vw;text-align:center;position:relative;z-index:10}
.gate-icon{font-size:48px;margin-bottom:16px;opacity:0.6}
.gate h1{font-family:'Orbitron',monospace;font-size:14px;font-weight:700;letter-spacing:5px;
  color:rgba(0,255,200,0.5);text-shadow:0 0 20px rgba(0,255,200,0.15);margin-bottom:6px}
.gate .sub{font-size:8px;letter-spacing:3px;opacity:0.2;text-transform:uppercase;margin-bottom:32px}

.input-group{position:relative;margin-bottom:16px}
.input-group input{width:100%;background:rgba(0,255,200,0.03);border:1px solid rgba(0,255,200,0.1);
  color:rgba(0,255,200,0.8);font-family:'Share Tech Mono',monospace;font-size:14px;
  padding:14px 16px;outline:none;letter-spacing:3px;text-align:center;transition:all 0.3s}
.input-group input:focus{border-color:rgba(0,255,200,0.3);box-shadow:0 0 20px rgba(0,255,200,0.05)}
.input-group input::placeholder{color:rgba(0,255,200,0.15);letter-spacing:2px;font-size:10px}

.submit-btn{width:100%;font-family:'Orbitron',monospace;font-size:9px;font-weight:700;letter-spacing:4px;
  padding:12px;background:rgba(0,255,200,0.05);color:rgba(0,255,200,0.4);
  border:1px solid rgba(0,255,200,0.12);cursor:pointer;transition:all 0.3s;text-transform:uppercase}
.submit-btn:hover{background:rgba(0,255,200,0.1);color:rgba(0,255,200,0.7);
  border-color:rgba(0,255,200,0.25);box-shadow:0 0 20px rgba(0,255,200,0.08)}

.error{font-size:9px;color:rgba(255,60,60,0.7);letter-spacing:1px;margin-top:12px;min-height:16px;
  text-shadow:0 0 8px rgba(255,60,60,0.2)}
.error.shake{animation:shake 0.4s ease}
@keyframes shake{0%,100%{transform:translateX(0)}25%{transform:translateX(-8px)}75%{transform:translateX(8px)}}

.footer{font-size:7px;letter-spacing:2px;opacity:0.1;margin-top:32px;text-transform:uppercase}

.corner{position:fixed;width:20px;height:20px;opacity:0.08}
.corner-tl{top:12px;left:12px;border-top:1px solid rgba(0,255,200,0.5);border-left:1px solid rgba(0,255,200,0.5)}
.corner-tr{top:12px;right:12px;border-top:1px solid rgba(0,255,200,0.5);border-right:1px solid rgba(0,255,200,0.5)}
.corner-bl{bottom:12px;left:12px;border-bottom:1px solid rgba(0,255,200,0.5);border-left:1px solid rgba(0,255,200,0.5)}
.corner-br{bottom:12px;right:12px;border-bottom:1px solid rgba(0,255,200,0.5);border-right:1px solid rgba(0,255,200,0.5)}

.decrypting{display:none;text-align:center}
.decrypting.show{display:block}
.decrypting .spinner{font-family:'Orbitron',monospace;font-size:10px;letter-spacing:3px;
  color:rgba(0,255,200,0.4);animation:pulse 1s infinite}
@keyframes pulse{0%,100%{opacity:1}50%{opacity:0.3}}
</style>
</head>
<body>

<div class="corner corner-tl"></div>
<div class="corner corner-tr"></div>
<div class="corner corner-bl"></div>
<div class="corner corner-br"></div>

<div class="gate" id="gate">
  <div class="gate-icon">🔒</div>
  <h1>MAGI SYSTEM</h1>
  <div class="sub">%%PAGE_TITLE%% &middot; Authentication Required</div>

  <form onsubmit="return handleSubmit(event)">
    <div class="input-group">
      <input type="password" id="pwd" placeholder="ACCESS CODE" autofocus autocomplete="off">
    </div>
    <button type="submit" class="submit-btn">AUTHENTICATE</button>
  </form>
  <div class="error" id="error"></div>
  <div class="footer">AES-256-GCM &middot; PBKDF2 100K ITERATIONS &middot; TEAMPLAYER.INC</div>
</div>

<div class="decrypting" id="decrypting">
  <div class="spinner">DECRYPTING...</div>
</div>

<script>
var ENCRYPTED = %%ENCRYPTED_DATA%%;

async function deriveKey(password, salt) {
  var enc = new TextEncoder();
  var keyMaterial = await crypto.subtle.importKey('raw', enc.encode(password), 'PBKDF2', false, ['deriveKey']);
  return crypto.subtle.deriveKey(
    {name:'PBKDF2', salt:salt, iterations:100000, hash:'SHA-256'},
    keyMaterial,
    {name:'AES-GCM', length:256},
    false,
    ['decrypt']
  );
}

async function decrypt(password) {
  var salt = Uint8Array.from(atob(ENCRYPTED.salt), function(c){return c.charCodeAt(0);});
  var iv = Uint8Array.from(atob(ENCRYPTED.iv), function(c){return c.charCodeAt(0);});
  var ct = Uint8Array.from(atob(ENCRYPTED.ct), function(c){return c.charCodeAt(0);});

  var key = await deriveKey(password, salt);
  var decrypted = await crypto.subtle.decrypt({name:'AES-GCM', iv:iv}, key, ct);
  return new TextDecoder().decode(decrypted);
}

async function handleSubmit(e) {
  e.preventDefault();
  var pwd = document.getElementById('pwd').value;
  if (!pwd) return false;

  var errEl = document.getElementById('error');
  errEl.textContent = '';
  errEl.classList.remove('shake');

  try {
    document.getElementById('gate').style.display = 'none';
    document.getElementById('decrypting').classList.add('show');

    var html = await decrypt(pwd);

    // Store auth state in sessionStorage
    sessionStorage.setItem('magi_auth', '1');

    // Replace entire document
    document.open();
    document.write(html);
    document.close();
  } catch(ex) {
    document.getElementById('gate').style.display = '';
    document.getElementById('decrypting').classList.remove('show');
    errEl.textContent = 'ACCESS DENIED — INVALID CODE';
    void errEl.offsetWidth;
    errEl.classList.add('shake');
    document.getElementById('pwd').value = '';
    document.getElementById('pwd').focus();
  }
  return false;
}
</script>
</body>
</html>'''

def build_secure(html_path: str, password: str, output_path: str, page_title: str):
    with open(html_path, 'r', encoding='utf-8') as f:
        content = f.read()

    plaintext = content.encode('utf-8')

    try:
        data = encrypt_aes_gcm(plaintext, password)
    except ImportError:
        print("  [!] cryptography 패키지 없음, pip install 시도...")
        os.system(f"{sys.executable} -m pip install cryptography -q")
        data = encrypt_aes_gcm(plaintext, password)

    gate = GATE_TEMPLATE
    gate = gate.replace('%%PAGE_TITLE%%', page_title)
    gate = gate.replace('%%ENCRYPTED_DATA%%', json.dumps(data))

    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(gate)

    size_kb = len(gate) / 1024
    print(f"  ✅ {output_path} ({size_kb:.0f}KB, AES-256-GCM)")

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 build-secure.py <password>")
        print("  index.html → index.html (encrypted)")
        print("  council.html → council.html (encrypted)")
        sys.exit(1)

    password = sys.argv[1]
    script_dir = os.path.dirname(os.path.abspath(__file__))

    # Backup originals to _src/
    src_dir = os.path.join(script_dir, '_src')
    os.makedirs(src_dir, exist_ok=True)

    files = [
        ('index.html', '3D VISUALIZATION'),
        ('council.html', '6-AXIS DELIBERATION'),
    ]

    for fname, title in files:
        src = os.path.join(script_dir, fname)
        if not os.path.exists(src):
            print(f"  ⚠️  {fname} not found, skipping")
            continue

        # Backup original
        backup = os.path.join(src_dir, fname)
        with open(src, 'r', encoding='utf-8') as f:
            original = f.read()
        with open(backup, 'w', encoding='utf-8') as f:
            f.write(original)

        # Encrypt in-place
        build_secure(src, password, src, title)

    print(f"\n  원본 백업: _src/")
    print(f"  비밀번호 변경: python3 build-secure.py <new-password>")

if __name__ == '__main__':
    main()
