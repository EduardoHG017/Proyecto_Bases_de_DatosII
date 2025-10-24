#!/bin/bash
# ===================================================================
# SCRIPT MANUAL PARA CONFIGURAR REPLICACIÓN
# ===================================================================
# Este script configura manualmente los nodos de replicación

echo "==========================================="
echo "  CONFIGURACIÓN MANUAL DE REPLICACIÓN"
echo "==========================================="

# Función para configurar standby
setup_standby() {
    echo ""
    echo "=== CONFIGURANDO NODO STANDBY ==="
    
    # Crear el contenedor standby manualmente
    docker run -d \
        --name postgresql-standby \
        --hostname postgresql-standby \
        --network proyecto_postgresql_postgresql-network \
        -p 5433:5432 \
        -e POSTGRES_HOST_AUTH_METHOD=trust \
        -v postgresql-standby-data:/var/lib/postgresql/data \
        -v ./scripts:/scripts \
        postgres:15
    
    echo "Esperando a que el contenedor esté listo..."
    sleep 10
    
    # Hacer pg_basebackup como usuario postgres
    echo "Realizando pg_basebackup..."
    docker exec -u postgres postgresql-standby bash -c "
        # Detener PostgreSQL si está ejecutándose
        pg_ctl stop -D /var/lib/postgresql/data -m fast 2>/dev/null || true
        
        # Limpiar directorio de datos
        rm -rf /var/lib/postgresql/data/*
        
        # Hacer pg_basebackup
        PGPASSWORD=replica123 pg_basebackup \
            -h postgresql-primary \
            -D /var/lib/postgresql/data \
            -U replicator \
            -v -P -R --wal-method=stream
        
        # Crear standby.signal
        touch /var/lib/postgresql/data/standby.signal
        
        # Iniciar PostgreSQL
        pg_ctl start -D /var/lib/postgresql/data -l /var/lib/postgresql/data/log
    "
    
    if [ $? -eq 0 ]; then
        echo "✅ Nodo standby configurado exitosamente"
    else
        echo "❌ Error configurando nodo standby"
    fi
}

# Función para configurar readonly
setup_readonly() {
    echo ""
    echo "=== CONFIGURANDO NODO READONLY ==="
    
    # Crear el contenedor readonly manualmente
    docker run -d \
        --name postgresql-readonly \
        --hostname postgresql-readonly \
        --network proyecto_postgresql_postgresql-network \
        -p 5434:5432 \
        -e POSTGRES_HOST_AUTH_METHOD=trust \
        -v postgresql-readonly-data:/var/lib/postgresql/data \
        -v ./scripts:/scripts \
        postgres:15
    
    echo "Esperando a que el contenedor esté listo..."
    sleep 10
    
    # Hacer pg_basebackup como usuario postgres
    echo "Realizando pg_basebackup para readonly..."
    docker exec -u postgres postgresql-readonly bash -c "
        # Detener PostgreSQL si está ejecutándose
        pg_ctl stop -D /var/lib/postgresql/data -m fast 2>/dev/null || true
        
        # Limpiar directorio de datos
        rm -rf /var/lib/postgresql/data/*
        
        # Hacer pg_basebackup
        PGPASSWORD=replica123 pg_basebackup \
            -h postgresql-primary \
            -D /var/lib/postgresql/data \
            -U replicator \
            -v -P -R --wal-method=stream
        
        # Crear standby.signal
        touch /var/lib/postgresql/data/standby.signal
        
        # Optimizar para readonly
        echo 'max_connections = 150' >> /var/lib/postgresql/data/postgresql.conf
        echo 'work_mem = 8MB' >> /var/lib/postgresql/data/postgresql.conf
        
        # Iniciar PostgreSQL
        pg_ctl start -D /var/lib/postgresql/data -l /var/lib/postgresql/data/log
    "
    
    if [ $? -eq 0 ]; then
        echo "✅ Nodo readonly configurado exitosamente"
    else
        echo "❌ Error configurando nodo readonly"
    fi
}

# Función para verificar estado
check_status() {
    echo ""
    echo "=== VERIFICANDO ESTADO DE REPLICACIÓN ==="
    
    echo "Estado de contenedores:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep postgresql
    
    echo ""
    echo "Estado de replicación desde el primario:"
    docker exec postgresql-primary psql -U admin -d proyecto_db -c "
        SELECT application_name, client_addr, state, sync_state 
        FROM pg_stat_replication;
    " 2>/dev/null || echo "No hay conexiones de replicación activas"
    
    echo ""
    echo "Probando conexión a standby:"
    docker exec postgresql-standby psql -U admin -d proyecto_db -c "
        SELECT 'Standby conectado', pg_is_in_recovery() as en_recovery;
    " 2>/dev/null || echo "Standby no disponible"
    
    echo ""
    echo "Probando conexión a readonly:"
    docker exec postgresql-readonly psql -U admin -d proyecto_db -c "
        SELECT 'Readonly conectado', pg_is_in_recovery() as en_recovery;
    " 2>/dev/null || echo "Readonly no disponible"
}

# Menú principal
echo ""
echo "Seleccione una opción:"
echo "1. Configurar nodo standby"
echo "2. Configurar nodo readonly"
echo "3. Configurar ambos nodos"
echo "4. Verificar estado"
echo "5. Salir"
echo ""

read -p "Ingrese su opción (1-5): " opcion

case $opcion in
    1)
        setup_standby
        check_status
        ;;
    2)
        setup_readonly
        check_status
        ;;
    3)
        setup_standby
        setup_readonly
        check_status
        ;;
    4)
        check_status
        ;;
    5)
        echo "Saliendo..."
        exit 0
        ;;
    *)
        echo "Opción inválida"
        exit 1
        ;;
esac

echo ""
echo "Script completado."