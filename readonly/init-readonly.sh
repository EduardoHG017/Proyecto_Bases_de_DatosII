#!/bin/bash
# ===================================================================
# SCRIPT DE INICIALIZACIÓN - NODO READONLY
# ===================================================================
# Script que se ejecuta durante la inicialización del contenedor readonly
# Configura la replicación desde el nodo primario para solo lectura

set -e

echo "=== INICIANDO CONFIGURACIÓN DEL NODO READONLY ==="

# Verificar si ya existe una instalación de PostgreSQL
if [ -d "/var/lib/postgresql/data" ] && [ "$(ls -A /var/lib/postgresql/data)" ]; then
    echo "Los datos de PostgreSQL ya existen. Verificando configuración de readonly..."
    
    # Verificar si es un standby
    if [ -f "/var/lib/postgresql/data/standby.signal" ]; then
        echo "Nodo configurado como readonly standby. Continuando..."
    else
        echo "Configurando nodo como readonly standby..."
        touch /var/lib/postgresql/data/standby.signal
    fi
else
    echo "Iniciando replicación desde el nodo primario para readonly..."
    
    # Esperar a que el nodo primario esté disponible
    echo "Esperando a que el nodo primario esté disponible..."
    until PGPASSWORD=replica123 pg_isready -h postgresql-primary -p 5432 -U replicator; do
        echo "Nodo primario no disponible, esperando..."
        sleep 5
    done
    
    echo "Nodo primario disponible. Iniciando pg_basebackup para readonly..."
    
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
    
    echo "Backup base para readonly completado. Configurando conexión al primario..."
fi

# Configurar conexión al primario en postgresql.auto.conf
cat >> /var/lib/postgresql/data/postgresql.auto.conf <<EOF
# Configuración de conexión al nodo primario para readonly
primary_conninfo = 'host=postgresql-primary port=5432 user=replicator password=replica123 application_name=readonly_node'
primary_slot_name = ''
EOF

echo "=== CONFIGURACIÓN DEL NODO READONLY COMPLETADA ==="
echo "Nodo readonly configurado y listo para consultas de solo lectura"
echo "Este nodo NO debe ser promovido a primario - está optimizado para lecturas"
echo "Puertos disponibles:"
echo "- Primario: localhost:5432"
echo "- Standby: localhost:5433"
echo "- Readonly: localhost:5434"