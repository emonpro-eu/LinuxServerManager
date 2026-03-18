#!/bin/bash

CONFIG_FILE="/etc/aide/aide.conf"
CRON_FILE="/etc/cron.daily/aide-check"
DB_FILE="/var/lib/aide/aide.db"

apply() {

  if check; then
    echo "[INFO] AIDE already configured. Skipping..."
    return 0
  fi

  echo "[INFO] Installing AIDE..."
  apt-get update -y
  apt-get install -y aide aide-common

  echo "[INFO] Writing configuration..."

  cat > "$CONFIG_FILE" <<'EOF'
@@define DBDIR /var/lib/aide

database=file:@@{DBDIR}/aide.db
database_out=file:@@{DBDIR}/aide.db.new
gzip_dbout=yes

NORMAL = p+i+n+u+g+s+m+c+sha256
SECURE = p+i+n+u+g+s+m+c+sha512

/bin        SECURE
/sbin       SECURE
/usr/bin    SECURE
/usr/sbin   SECURE
/lib        SECURE
/lib64      SECURE
/boot       SECURE
/etc        NORMAL
/root       NORMAL
/opt        NORMAL

!/proc
!/sys
!/dev
!/run
!/tmp
!/var/tmp
!/var/log
!/var/cache
EOF

  echo "[INFO] Initializing database..."
  aideinit

  if [ -f /var/lib/aide/aide.db.new ]; then
    mv /var/lib/aide/aide.db.new "$DB_FILE"
  fi

  echo "[INFO] Creating daily cron job..."

  cat > "$CRON_FILE" <<'EOF'
#!/bin/bash
/usr/bin/aide --check | /usr/bin/logger -t aide
EOF

  chmod +x "$CRON_FILE"

  echo "[INFO] AIDE configured successfully."
}

check() {

  # 1️⃣ pachet instalat?
  if ! dpkg -l | grep -q "^ii  aide "; then
    return 1
  fi

  # 2️⃣ config există?
  if [ ! -f "$CONFIG_FILE" ]; then
    return 1
  fi

  # 3️⃣ DB există?
  if [ ! -f "$DB_FILE" ]; then
    return 1
  fi

  # 4️⃣ cron există?
  if [ ! -f "$CRON_FILE" ]; then
    return 1
  fi

  # 5️⃣ verificăm o semnătură din config (ca să fim siguri că e a noastră)
  if ! grep -q "/bin        SECURE" "$CONFIG_FILE"; then
    return 1
  fi

  return 0
}