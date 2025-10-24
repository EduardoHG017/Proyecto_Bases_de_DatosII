# ===================================================================
# COMANDOS POWERSHELL PARA WINDOWS
# ===================================================================
# Este archivo contiene comandos de PowerShell equivalentes para Windows
# Uso: .\comandos.ps1 [accion]

param(
    [string]$accion = "menu"
)

# Configuración
$proyectoDir = Get-Location
$scriptDir = Join-Path $proyectoDir "scripts"

# Función para mostrar el menú principal
function Show-Menu {
    Clear-Host
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "  PROYECTO POSTGRESQL - COMANDOS WINDOWS" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Seleccione una opción:" -ForegroundColor Yellow
    Write-Host "1. Levantar clúster completo" -ForegroundColor Green
    Write-Host "2. Ver estado del clúster" -ForegroundColor Blue
    Write-Host "3. Monitoreo en tiempo real" -ForegroundColor Blue
    Write-Host "4. Ejecutar failover manual" -ForegroundColor Red
    Write-Host "5. Crear backup completo" -ForegroundColor Magenta
    Write-Host "6. Crear backup incremental" -ForegroundColor Magenta
    Write-Host "7. Ver logs de contenedores" -ForegroundColor Gray
    Write-Host "8. Conectar a nodos (psql)" -ForegroundColor Yellow
    Write-Host "9. Configurar replicación manual" -ForegroundColor Cyan
    Write-Host "10. Detener clúster" -ForegroundColor Red
    Write-Host "11. Limpiar todo y reiniciar" -ForegroundColor Red
    Write-Host "0. Salir" -ForegroundColor White
    Write-Host ""
}

# Función para levantar el clúster
function Start-Cluster {
    Write-Host "🚀 Levantando clúster PostgreSQL..." -ForegroundColor Green
    
    # Verificar que Docker esté ejecutándose
    try {
        docker --version | Out-Null
        Write-Host "✅ Docker está disponible" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Error: Docker no está disponible o no está ejecutándose" -ForegroundColor Red
        return
    }
    
    # Levantar contenedores
    Write-Host "Ejecutando docker-compose up -d..." -ForegroundColor Yellow
    docker-compose up -d
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Contenedores iniciados exitosamente" -ForegroundColor Green
        
        Write-Host "⏳ Esperando a que PostgreSQL esté listo (30 segundos)..." -ForegroundColor Yellow
        Start-Sleep -Seconds 30
        
        # Verificar estado
        Write-Host "📊 Estado de contenedores:" -ForegroundColor Cyan
        docker-compose ps
        
        Write-Host ""
        Write-Host "🔗 INFORMACIÓN DE CONEXIÓN:" -ForegroundColor Cyan
        Write-Host "  • Primario:  localhost:5432 (lectura/escritura)" -ForegroundColor White
        Write-Host "  • Standby:   localhost:5433 (solo lectura)" -ForegroundColor White
        Write-Host "  • Readonly:  localhost:5434 (solo lectura)" -ForegroundColor White
        Write-Host "  • Usuario:   admin" -ForegroundColor White
        Write-Host "  • Password:  admin123" -ForegroundColor White
        Write-Host "  • Database:  proyecto_db" -ForegroundColor White
    }
    else {
        Write-Host "❌ Error al iniciar contenedores" -ForegroundColor Red
    }
}

# Función para ver estado
function Show-Status {
    Write-Host "📊 Estado del clúster PostgreSQL..." -ForegroundColor Cyan
    
    Write-Host ""
    Write-Host "📦 ESTADO DE CONTENEDORES:" -ForegroundColor Yellow
    docker-compose ps
    
    Write-Host ""
    Write-Host "🔄 ESTADO DE REPLICACIÓN:" -ForegroundColor Yellow
    $result = docker exec postgresql-primary psql -U admin -d proyecto_db -c "SELECT application_name, client_addr, state, sync_state FROM pg_stat_replication;" 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host $result
    }
    else {
        Write-Host "❌ No se pudo obtener estado de replicación (primario no disponible)" -ForegroundColor Red
    }
    
    Write-Host ""
    Write-Host "🏥 ESTADO DE NODOS:" -ForegroundColor Yellow
    
    # Verificar primario
    Write-Host "📍 Nodo Primario:" -ForegroundColor Cyan
    $result = docker exec postgresql-primary psql -U admin -d proyecto_db -t -c "SELECT CASE WHEN pg_is_in_recovery() THEN 'STANDBY' ELSE 'PRIMARIO' END;" 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  Estado: $($result.Trim())" -ForegroundColor Green
    }
    else {
        Write-Host "  ❌ No disponible" -ForegroundColor Red
    }
    
    # Verificar standby
    Write-Host "📍 Nodo Standby:" -ForegroundColor Cyan
    $result = docker exec postgresql-standby psql -U admin -d proyecto_db -t -c "SELECT CASE WHEN pg_is_in_recovery() THEN 'STANDBY' ELSE 'PRIMARIO' END;" 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  Estado: $($result.Trim())" -ForegroundColor Green
    }
    else {
        Write-Host "  ❌ No disponible" -ForegroundColor Red
    }
    
    # Verificar readonly
    Write-Host "📍 Nodo Readonly:" -ForegroundColor Cyan
    $result = docker exec postgresql-readonly psql -U admin -d proyecto_db -t -c "SELECT CASE WHEN pg_is_in_recovery() THEN 'READONLY' ELSE 'PRIMARIO' END;" 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  Estado: $($result.Trim())" -ForegroundColor Green
    }
    else {
        Write-Host "  ❌ No disponible" -ForegroundColor Red
    }
}

# Función para monitoreo continuo
function Start-Monitoring {
    Write-Host "🔄 Iniciando monitoreo continuo..." -ForegroundColor Cyan
    Write-Host "Presione Ctrl+C para detener" -ForegroundColor Yellow
    Write-Host ""
    
    while ($true) {
        Clear-Host
        Write-Host "MONITOREO EN TIEMPO REAL - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
        Write-Host "===============================================" -ForegroundColor Cyan
        
        Show-Status
        
        Write-Host ""
        Write-Host "⏰ Actualizando en 10 segundos..." -ForegroundColor Gray
        Start-Sleep -Seconds 10
    }
}

# Función para failover
function Start-Failover {
    Write-Host "⚠️  FAILOVER MANUAL" -ForegroundColor Red
    Write-Host "==================" -ForegroundColor Red
    Write-Host ""
    Write-Host "ATENCIÓN: Esta operación promoverá el nodo standby a primario" -ForegroundColor Yellow
    Write-Host "¿Está seguro de continuar? (S/N): " -NoNewline -ForegroundColor Red
    
    $confirm = Read-Host
    if ($confirm -eq "S" -or $confirm -eq "s") {
        Write-Host ""
        Write-Host "🔄 Ejecutando promoción del standby..." -ForegroundColor Yellow
        
        $result = docker exec postgresql-standby pg_ctl promote -D /var/lib/postgresql/data
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Standby promovido exitosamente" -ForegroundColor Green
            
            Start-Sleep -Seconds 5
            
            # Verificar promoción
            Write-Host "🔍 Verificando estado post-failover..." -ForegroundColor Cyan
            $recoveryStatus = docker exec postgresql-standby psql -U admin -d proyecto_db -t -c "SELECT pg_is_in_recovery();" 2>$null
            
            if ($recoveryStatus -like "*f*") {
                Write-Host "✅ FAILOVER EXITOSO: El standby ahora es el primario" -ForegroundColor Green
                Write-Host "📍 Nuevo primario disponible en puerto 5433" -ForegroundColor Cyan
                
                # Insertar log de failover
                docker exec postgresql-standby psql -U admin -d proyecto_db -c "INSERT INTO proyecto.logs_replicacion (nodo, evento) VALUES ('failover', 'Failover ejecutado desde PowerShell');" 2>$null
            }
            else {
                Write-Host "❌ Error: La promoción no se completó correctamente" -ForegroundColor Red
            }
        }
        else {
            Write-Host "❌ Error durante la promoción" -ForegroundColor Red
        }
    }
    else {
        Write-Host "Failover cancelado" -ForegroundColor Yellow
    }
}

# Función para backup completo
function Create-FullBackup {
    Write-Host "💾 Creando backup completo..." -ForegroundColor Magenta
    
    # Verificar que el primario esté disponible
    $result = docker exec postgresql-primary pg_isready -U admin -d proyecto_db 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ El nodo primario no está disponible" -ForegroundColor Red
        return
    }
    
    $fecha = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupFile = "/backups/full/full_backup_$fecha.tar.gz"
    
    Write-Host "📁 Archivo de destino: $backupFile" -ForegroundColor Cyan
    Write-Host "⏳ Ejecutando pg_basebackup..." -ForegroundColor Yellow
    
    $command = @"
PGPASSWORD=admin123 pg_basebackup -h localhost -D /tmp/backup_$fecha -U admin -v -P -W -F tar -z -Z 6 && mv /tmp/backup_$fecha.tar.gz $backupFile && rm -rf /tmp/backup_$fecha
"@
    
    $result = docker exec postgresql-primary bash -c $command
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Backup completo creado exitosamente" -ForegroundColor Green
        
        # Obtener tamaño del archivo
        $size = docker exec postgresql-primary ls -lh $backupFile 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "📊 Tamaño del backup: $($size.Split()[4])" -ForegroundColor Cyan
        }
        
        # Registrar en la base de datos
        docker exec postgresql-primary psql -U admin -d proyecto_db -c "INSERT INTO proyecto.logs_replicacion (nodo, evento) VALUES ('backup', 'Backup completo desde PowerShell: $backupFile');" 2>$null
    }
    else {
        Write-Host "❌ Error al crear el backup" -ForegroundColor Red
    }
}

# Función para backup incremental
function Create-IncrementalBackup {
    Write-Host "📝 Creando backup incremental..." -ForegroundColor Magenta
    
    $fecha = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupFile = "/backups/incremental/incremental_backup_$fecha.tar.gz"
    
    Write-Host "📁 Archivo de destino: $backupFile" -ForegroundColor Cyan
    Write-Host "⏳ Creando backup de archivos WAL recientes..." -ForegroundColor Yellow
    
    $command = @"
cd /backups/wal_archive && find . -type f -name '0*' -mtime -1 > /tmp/wal_files_$fecha.list && if [ -s /tmp/wal_files_$fecha.list ]; then tar -czf $backupFile -T /tmp/wal_files_$fecha.list; else touch $backupFile; fi && rm -f /tmp/wal_files_$fecha.list
"@
    
    $result = docker exec postgresql-primary bash -c $command
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Backup incremental creado exitosamente" -ForegroundColor Green
        
        # Registrar en la base de datos
        docker exec postgresql-primary psql -U admin -d proyecto_db -c "INSERT INTO proyecto.logs_replicacion (nodo, evento) VALUES ('backup', 'Backup incremental desde PowerShell: $backupFile');" 2>$null
    }
    else {
        Write-Host "❌ Error al crear el backup incremental" -ForegroundColor Red
    }
}

# Función para ver logs
function Show-Logs {
    Write-Host "📋 Seleccione el contenedor para ver logs:" -ForegroundColor Cyan
    Write-Host "1. Primary (postgresql-primary)" -ForegroundColor Green
    Write-Host "2. Standby (postgresql-standby)" -ForegroundColor Blue
    Write-Host "3. Readonly (postgresql-readonly)" -ForegroundColor Magenta
    Write-Host "4. Todos los contenedores" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Ingrese su opción (1-4): " -NoNewline
    
    $opcion = Read-Host
    
    switch ($opcion) {
        "1" { 
            Write-Host "📋 Logs del nodo Primary:" -ForegroundColor Green
            docker logs --tail 50 postgresql-primary 
        }
        "2" { 
            Write-Host "📋 Logs del nodo Standby:" -ForegroundColor Blue
            docker logs --tail 50 postgresql-standby 
        }
        "3" { 
            Write-Host "📋 Logs del nodo Readonly:" -ForegroundColor Magenta
            docker logs --tail 50 postgresql-readonly 
        }
        "4" { 
            Write-Host "📋 Logs de todos los contenedores:" -ForegroundColor Yellow
            docker-compose logs --tail 20
        }
        default { 
            Write-Host "Opción inválida" -ForegroundColor Red 
        }
    }
}

# Función para conectar con psql
function Connect-ToNode {
    Write-Host "🔗 Seleccione el nodo para conectar:" -ForegroundColor Cyan
    Write-Host "1. Primary (puerto 5432) - Lectura/Escritura" -ForegroundColor Green
    Write-Host "2. Standby (puerto 5433) - Solo Lectura" -ForegroundColor Blue
    Write-Host "3. Readonly (puerto 5434) - Solo Lectura" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "Ingrese su opción (1-3): " -NoNewline
    
    $opcion = Read-Host
    
    switch ($opcion) {
        "1" { 
            Write-Host "🔗 Conectando al nodo Primary..." -ForegroundColor Green
            Write-Host "Comando: psql -h localhost -p 5432 -U admin -d proyecto_db" -ForegroundColor Gray
            & psql -h localhost -p 5432 -U admin -d proyecto_db
        }
        "2" { 
            Write-Host "🔗 Conectando al nodo Standby..." -ForegroundColor Blue
            Write-Host "Comando: psql -h localhost -p 5433 -U admin -d proyecto_db" -ForegroundColor Gray
            & psql -h localhost -p 5433 -U admin -d proyecto_db
        }
        "3" { 
            Write-Host "🔗 Conectando al nodo Readonly..." -ForegroundColor Magenta
            Write-Host "Comando: psql -h localhost -p 5434 -U admin -d proyecto_db" -ForegroundColor Gray
            & psql -h localhost -p 5434 -U admin -d proyecto_db
        }
        default { 
            Write-Host "Opción inválida" -ForegroundColor Red 
        }
    }
}

# Función para detener clúster
function Stop-Cluster {
    Write-Host "🛑 Deteniendo clúster..." -ForegroundColor Red
    Write-Host "¿Está seguro? (S/N): " -NoNewline
    
    $confirm = Read-Host
    if ($confirm -eq "S" -or $confirm -eq "s") {
        docker-compose down
        Write-Host "✅ Clúster detenido" -ForegroundColor Green
    }
    else {
        Write-Host "Operación cancelada" -ForegroundColor Yellow
    }
}

# Función para limpiar todo
function Clean-All {
    Write-Host "🧹 LIMPIEZA COMPLETA" -ForegroundColor Red
    Write-Host "===================" -ForegroundColor Red
    Write-Host "⚠️  ATENCIÓN: Esto eliminará todos los datos y volúmenes" -ForegroundColor Yellow
    Write-Host "¿Está seguro de continuar? (S/N): " -NoNewline
    
    $confirm = Read-Host
    if ($confirm -eq "S" -or $confirm -eq "s") {
        Write-Host "🛑 Deteniendo contenedores..." -ForegroundColor Yellow
        docker-compose down
        
        Write-Host "🗑️  Eliminando volúmenes..." -ForegroundColor Yellow
        docker volume rm proyecto_postgresql_postgresql-primary-data 2>$null
        docker volume rm proyecto_postgresql_postgresql-standby-data 2>$null
        docker volume rm proyecto_postgresql_postgresql-readonly-data 2>$null
        
        Write-Host "🚀 Reiniciando clúster..." -ForegroundColor Green
        docker-compose up -d
        
        Write-Host "✅ Limpieza completada y clúster reiniciado" -ForegroundColor Green
    }
    else {
        Write-Host "Operación cancelada" -ForegroundColor Yellow
    }
}

# Procesador principal de comandos
switch ($accion) {
    "iniciar" { Start-Cluster }
    "estado" { Show-Status }
    "monitor" { Start-Monitoring }
    "failover" { Start-Failover }
    "backup-completo" { Create-FullBackup }
    "backup-incremental" { Create-IncrementalBackup }
    "logs" { Show-Logs }
    "conectar" { Connect-ToNode }
    "replicacion-manual" { 
        Write-Host "🔧 Configurando replicación manual..." -ForegroundColor Cyan
        & .\setup_replication_manual.ps1
    }
    "detener" { Stop-Cluster }
    "limpiar" { Clean-All }
    "menu" {
        do {
            Show-Menu
            $opcion = Read-Host "Ingrese su opción (0-10)"
            
            switch ($opcion) {
                "1" { Start-Cluster; Read-Host "Presione Enter para continuar" }
                "2" { Show-Status; Read-Host "Presione Enter para continuar" }
                "3" { Start-Monitoring }
                "4" { Start-Failover; Read-Host "Presione Enter para continuar" }
                "5" { Create-FullBackup; Read-Host "Presione Enter para continuar" }
                "6" { Create-IncrementalBackup; Read-Host "Presione Enter para continuar" }
                "7" { Show-Logs; Read-Host "Presione Enter para continuar" }
                "8" { Connect-ToNode; Read-Host "Presione Enter para continuar" }
                "9" { 
                    Write-Host "🔧 Configurando replicación manual..." -ForegroundColor Cyan
                    & .\setup_replication_manual.ps1
                    Read-Host "Presione Enter para continuar" 
                }
                "10" { Stop-Cluster; Read-Host "Presione Enter para continuar" }
                "11" { Clean-All; Read-Host "Presione Enter para continuar" }
                "0" { 
                    Write-Host "¡Hasta luego!" -ForegroundColor Green
                    break
                }
                default { 
                    Write-Host "Opción inválida. Presione Enter para continuar" -ForegroundColor Red
                    Read-Host
                }
            }
        } while ($opcion -ne "0")
    }
    default {
        Write-Host "Uso: .\comandos.ps1 [accion]" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Acciones disponibles:" -ForegroundColor Cyan
        Write-Host "  iniciar             - Levantar clúster completo" -ForegroundColor Green
        Write-Host "  estado              - Ver estado del clúster" -ForegroundColor Blue
        Write-Host "  monitor             - Monitoreo en tiempo real" -ForegroundColor Blue
        Write-Host "  failover            - Ejecutar failover manual" -ForegroundColor Red
        Write-Host "  backup-completo     - Crear backup completo" -ForegroundColor Magenta
        Write-Host "  backup-incremental  - Crear backup incremental" -ForegroundColor Magenta
        Write-Host "  logs                - Ver logs de contenedores" -ForegroundColor Gray
        Write-Host "  conectar            - Conectar a nodos con psql" -ForegroundColor Yellow
        Write-Host "  replicacion-manual  - Configurar replicación manual" -ForegroundColor Cyan
        Write-Host "  detener             - Detener clúster" -ForegroundColor Red
        Write-Host "  limpiar             - Limpiar todo y reiniciar" -ForegroundColor Red
        Write-Host "  menu                - Mostrar menú interactivo" -ForegroundColor White
        Write-Host ""
        Write-Host "Ejemplos:" -ForegroundColor Yellow
        Write-Host "  .\comandos.ps1 iniciar" -ForegroundColor Gray
        Write-Host "  .\comandos.ps1 estado" -ForegroundColor Gray
        Write-Host "  .\comandos.ps1 menu" -ForegroundColor Gray
    }
}