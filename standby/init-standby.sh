#!/bin/bash
# ===================================================================
# SCRIPT DE INICIALIZACIÓN - NODO STANDBY
# ===================================================================
# Script que se ejecuta durante la inicialización del contenedor standby
# Configura la replicación desde el nodo primario

set -e

echo "=== INICIANDO CONFIGURACIÓN DEL NODO STANDBY ==="

# Verificar si ya existe una instalación de PostgreSQL
if [ -d "/var/lib/postgresql/data" ] && [ "$(ls -A /var/lib/postgresql/data)" ]; then
    echo "Los datos de PostgreSQL ya existen. Verificando configuración de standby..."
    
    # Verificar si es un standby
    if [ -f "/var/lib/postgresql/data/standby.signal" ]; then
        echo "Nodo configurado como standby. Continuando..."
    else
        echo "Configurando nodo como standby..."
        touch /var/lib/postgresql/data/standby.signal
    fi
else
    echo "Iniciando replicación desde el nodo primario..."
    
    # Esperar a que el nodo primario esté disponible
    echo "Esperando a que el nodo primario esté disponible..."
    until PGPASSWORD=replica123 pg_isready -h postgresql-primary -p 5432 -U replicator; do
        echo "Nodo primario no disponible, esperando..."
        sleep 5
    done
    
    echo "Nodo primario disponible. Iniciando pg_basebackup..."
    
    # Realizar backup base desde el primario
    PGPASSWORD=replica123 pg_basebackup \
        -h postgresql-primary \
        -D /var/lib/postgresql/data \
        -U replicator \
        -W \
        -v \
        -P \
        -R
    
    # Crear archivo standby.signal
    touch /var/lib/postgresql/data/standby.signal
    
    echo "Backup base completado. Configurando conexión al primario..."
fi

# Configurar conexión al primario en postgresql.auto.conf
cat >> /var/lib/postgresql/data/postgresql.auto.conf <<EOF
# Configuración de conexión al nodo primario
primary_conninfo = 'host=postgresql-primary port=5432 user=replicator password=replica123 application_name=standby_node'
primary_slot_name = ''
EOF

echo "=== CONFIGURACIÓN DEL NODO STANDBY COMPLETADA ==="
echo "Nodo standby configurado y listo para replicación streaming"
echo "Este nodo puede ser promovido a primario usando: pg_ctl promote -D /var/lib/postgresql/data"