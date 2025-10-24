#!/bin/bash
# ===================================================================
# SCRIPT DE INICIALIZACIÓN - NODO PRIMARIO SIMPLIFICADO
# ===================================================================

set -e

echo "=== CONFIGURANDO NODO PRIMARIO ==="

# Configurar PostgreSQL para replicación
cat >> "$PGDATA/postgresql.conf" << 'EOF'

# Configuración para replicación streaming
wal_level = replica
max_wal_senders = 10
wal_keep_size = 512MB
hot_standby = on
archive_mode = on
archive_command = 'cp %p /backups/wal_archive/%f 2>/dev/null || true'
listen_addresses = '*'
max_connections = 100
log_statement = 'all'
EOF

# Configurar pg_hba.conf
cat >> "$PGDATA/pg_hba.conf" << 'EOF'

# Replicación
host    replication     replicator      172.20.0.0/16          trust
host    all             all             172.20.0.0/16          trust
EOF
hot_standby = on
archive_mode = on
archive_command = 'cp %p /backups/wal_archive/%f 2>/dev/null || true'
wal_keep_size = 512MB

# Configuración de logging
logging_collector = on
log_statement = 'all'
log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h '

EOF

# Configurar pg_hba.conf para permitir replicación
cat >> "$PGDATA/pg_hba.conf" <<EOF

# Configuración para replicación
host replication replicator all trust
host all all all trust

EOF

# Esperar a que PostgreSQL esté completamente iniciado
until pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB"; do
  echo "Esperando a que PostgreSQL esté listo..."
  sleep 2
done

echo "PostgreSQL está listo. Configurando replicación..."

# Crear usuario para replicación
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    -- Crear usuario replicator con permisos de replicación
    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'replicator') THEN
            CREATE ROLE replicator WITH REPLICATION PASSWORD 'replica123' LOGIN;
            GRANT CONNECT ON DATABASE $POSTGRES_DB TO replicator;
        END IF;
    END
    \$\$;

    -- Crear esquema para datos de ejemplo
    CREATE SCHEMA IF NOT EXISTS proyecto;

    -- Crear tabla de ejemplo para pruebas
    CREATE TABLE IF NOT EXISTS proyecto.usuarios (
        id SERIAL PRIMARY KEY,
        nombre VARCHAR(100) NOT NULL,
        email VARCHAR(150) UNIQUE NOT NULL,
        fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        activo BOOLEAN DEFAULT true
    );

    -- Insertar datos de ejemplo
    INSERT INTO proyecto.usuarios (nombre, email) VALUES 
        ('Juan Pérez', 'juan.perez@email.com'),
        ('María García', 'maria.garcia@email.com'),
        ('Carlos López', 'carlos.lopez@email.com'),
        ('Ana Martínez', 'ana.martinez@email.com'),
        ('Luis Rodríguez', 'luis.rodriguez@email.com')
    ON CONFLICT (email) DO NOTHING;

    -- Crear tabla de logs para monitoreo
    CREATE TABLE IF NOT EXISTS proyecto.logs_replicacion (
        id SERIAL PRIMARY KEY,
        nodo VARCHAR(50) NOT NULL,
        evento VARCHAR(200) NOT NULL,
        timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

    -- Insertar log inicial
    INSERT INTO proyecto.logs_replicacion (nodo, evento) VALUES 
        ('primary', 'Nodo primario inicializado correctamente');
EOSQL

# Recargar configuración
psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT pg_reload_conf();"

echo "=== CONFIGURACIÓN DEL NODO PRIMARIO COMPLETADA ==="

# Crear directorio para archivos WAL si no existe
mkdir -p /backups/wal_archive
chmod 755 /backups/wal_archive

echo "Directorio de archivos WAL creado: /backups/wal_archive"
echo "Nodo primario listo para recibir conexiones y replicar datos"