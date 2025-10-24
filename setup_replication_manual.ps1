# ===================================================================
# SCRIPT MANUAL PARA CONFIGURAR REPLICACIÓN - VERSIÓN POWERSHELL
# ===================================================================

Write-Host "==========================================="
Write-Host "  CONFIGURACIÓN MANUAL DE REPLICACIÓN"
Write-Host "==========================================="

# Función para configurar standby
function Setup-Standby {
    Write-Host ""
    Write-Host "=== CONFIGURANDO NODO STANDBY ===" -ForegroundColor Yellow
    
    # Crear el contenedor standby manualmente
    docker run -d `
        --name postgresql-standby `
        --hostname postgresql-standby `
        --network proyecto_postgresql_postgresql-network `
        -p 5433:5432 `
        -e POSTGRES_HOST_AUTH_METHOD=trust `
        -v postgresql-standby-data:/var/lib/postgresql/data `
        -v ${PWD}/scripts:/scripts `
        postgres:15
    
    Write-Host "Esperando a que el contenedor esté listo..."
    Start-Sleep -Seconds 10
    
    # Hacer pg_basebackup como usuario postgres
    Write-Host "Realizando pg_basebackup..."
    
    $command = @"
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
"@
    
    docker exec -u postgres postgresql-standby bash -c $command
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Nodo standby configurado exitosamente" -ForegroundColor Green
    } else {
        Write-Host "❌ Error configurando nodo standby" -ForegroundColor Red
    }
}

# Función para configurar readonly
function Setup-Readonly {
    Write-Host ""
    Write-Host "=== CONFIGURANDO NODO READONLY ===" -ForegroundColor Yellow
    
    # Crear el contenedor readonly manualmente
    docker run -d `
        --name postgresql-readonly `
        --hostname postgresql-readonly `
        --network proyecto_postgresql_postgresql-network `
        -p 5434:5432 `
        -e POSTGRES_HOST_AUTH_METHOD=trust `
        -v postgresql-readonly-data:/var/lib/postgresql/data `
        -v ${PWD}/scripts:/scripts `
        postgres:15
    
    Write-Host "Esperando a que el contenedor esté listo..."
    Start-Sleep -Seconds 10
    
    # Hacer pg_basebackup como usuario postgres
    Write-Host "Realizando pg_basebackup para readonly..."
    
    $command = @"
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
"@
    
    docker exec -u postgres postgresql-readonly bash -c $command
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Nodo readonly configurado exitosamente" -ForegroundColor Green
    } else {
        Write-Host "❌ Error configurando nodo readonly" -ForegroundColor Red
    }
}

# Función para verificar estado
function Check-Status {
    Write-Host ""
    Write-Host "=== VERIFICANDO ESTADO DE REPLICACIÓN ===" -ForegroundColor Yellow
    
    Write-Host "Estado de contenedores:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | Select-String postgresql
    
    Write-Host ""
    Write-Host "Estado de replicación desde el primario:"
    docker exec postgresql-primary psql -U admin -d proyecto_db -c "SELECT application_name, client_addr, state, sync_state FROM pg_stat_replication;" 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "No hay conexiones de replicación activas" -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "Probando conexión a standby:"
    docker exec postgresql-standby psql -U admin -d proyecto_db -c "SELECT 'Standby conectado', pg_is_in_recovery() as en_recovery;" 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Standby no disponible" -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "Probando conexión a readonly:"
    docker exec postgresql-readonly psql -U admin -d proyecto_db -c "SELECT 'Readonly conectado', pg_is_in_recovery() as en_recovery;" 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Readonly no disponible" -ForegroundColor Yellow
    }
}

# Menú principal
Write-Host ""
Write-Host "Seleccione una opción:"
Write-Host "1. Configurar nodo standby"
Write-Host "2. Configurar nodo readonly"
Write-Host "3. Configurar ambos nodos"
Write-Host "4. Verificar estado"
Write-Host "5. Salir"
Write-Host ""

$opcion = Read-Host "Ingrese su opción (1-5)"

switch ($opcion) {
    1 {
        Setup-Standby
        Check-Status
    }
    2 {
        Setup-Readonly
        Check-Status
    }
    3 {
        Setup-Standby
        Setup-Readonly
        Check-Status
    }
    4 {
        Check-Status
    }
    5 {
        Write-Host "Saliendo..."
        exit 0
    }
    default {
        Write-Host "Opción inválida" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "Script completado." -ForegroundColor Green