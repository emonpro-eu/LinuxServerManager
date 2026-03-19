#!/bin/bash

apply() {

  if check; then
    echo "[INFO] Banner already configured."
    return 0
  fi

  cat <<'EOF' > /etc/issue
***************************************************************************
                              NOTIFICARE CĂTRE UTILIZATORI
***************************************************************************

Acest sistem este proprietatea EXIMPROD GRUP și este destinat exclusiv
utilizării de către persoane autorizate.

Toate activitățile desfășurate pe acest sistem sunt monitorizate,
înregistrate și pot face obiectul auditării. Prin accesarea acestui
sistem, confirmați că nu aveți nicio așteptare rezonabilă de confidențialitate
cu privire la comunicațiile sau datele procesate prin intermediul acestuia.

Accesul, utilizarea sau modificarea neautorizată a acestui sistem sunt
strict interzise și pot atrage sancțiuni disciplinare, răspundere civilă
și/sau penală, conform legislației aplicabile.

Dacă nu sunteți un utilizator autorizat, deconectați-vă imediat.

***************************************************************************
EOF

  cp /etc/issue /etc/issue.net
  cp /etc/issue /etc/motd

  chmod 644 /etc/issue /etc/issue.net /etc/motd

  echo "[INFO] Banner configured."
}

check() {

  grep -q "NOTIFICARE CĂTRE UTILIZATORI" /etc/issue || return 1
  grep -q "NOTIFICARE CĂTRE UTILIZATORI" /etc/issue.net || return 1

  return 0
}