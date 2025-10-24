#!/bin/bash
# ===================================================================
# SCRIPT DE CONFIGURACIÓN PARA REPLICA STANDBY
# ===================================================================

set -e

echo "=== CONFIGURANDO NODO STANDBY ==="

# Solo configurar si es la primera vez
if [ ! -f /var/lib/postgresql/data/replica_configured ]; then
    echo "Primera configuración del standby..."
    
    # Configurar postgresql.conf para replicación
    cat >> /var/lib/postgresql/data/postgresql.conf << 'EOF'

# Configuración para replicación streaming standby
wal_level = replica
max_wal_senders = 10
hot_standby = on
hot_standby_feedback = on
wal_keep_size = 512MB
max_connections = 100
shared_buffers = 128MB

# Configuración de recovery
primary_conninfo = 'host=postgresql-primary port=5432 user=replicator password=replica123 application_name=standby_node'
restore_command = 'cp /backups/wal_archive/%f %p 2>/dev/null || true'
EOF

    # Señalar que es un standby
    touch /var/lib/postgresql/data/standby.signal
    
    # Marcar como configurado
    touch /var/lib/postgresql/data/replica_configured
    
    echo "✅ Configuración de standby completada"
else
    echo "Standby ya configurado previamente"
fi