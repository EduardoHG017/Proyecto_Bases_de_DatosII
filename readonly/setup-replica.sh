#!/bin/bash
# ===================================================================
# SCRIPT DE CONFIGURACIÓN PARA REPLICA READONLY
# ===================================================================

set -e

echo "=== CONFIGURANDO NODO READONLY ==="

# Solo configurar si es la primera vez
if [ ! -f /var/lib/postgresql/data/replica_configured ]; then
    echo "Primera configuración del readonly..."
    
    # Configurar postgresql.conf para replicación
    cat >> /var/lib/postgresql/data/postgresql.conf << 'EOF'

# Configuración para replicación streaming readonly
wal_level = replica
max_wal_senders = 10
hot_standby = on
hot_standby_feedback = on
wal_keep_size = 256MB
max_connections = 150

# Optimizaciones para readonly
work_mem = 8MB
effective_cache_size = 1GB
random_page_cost = 1.0
shared_buffers = 256MB

# Configuración de recovery
primary_conninfo = 'host=postgresql-primary port=5432 user=replicator password=replica123 application_name=readonly_node'
restore_command = 'cp /backups/wal_archive/%f %p 2>/dev/null || true'
EOF

    # Señalar que es un standby
    touch /var/lib/postgresql/data/standby.signal
    
    # Marcar como configurado
    touch /var/lib/postgresql/data/replica_configured
    
    echo "✅ Configuración de readonly completada"
else
    echo "Readonly ya configurado previamente"
fi