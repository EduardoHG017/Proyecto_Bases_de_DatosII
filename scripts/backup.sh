#!/bin/bash
# ===================================================================
# SCRIPT DE RESPALDOS AUTOMÁTICOS
# ===================================================================
# Script para realizar respaldos completos e incrementales
# Política: Backup completo semanal + backup incremental diario
# Retención: 7 días

set -e

# Configuración
BACKUP_DIR="/backups"
WAL_ARCHIVE_DIR="$BACKUP_DIR/wal_archive"
FULL_BACKUP_DIR="$BACKUP_DIR/full"
INCREMENTAL_BACKUP_DIR="$BACKUP_DIR/incremental"
LOG_FILE="$BACKUP_DIR/backup.log"
RETENTION_DAYS=7

# Crear directorios si no existen
mkdir -p "$FULL_BACKUP_DIR" "$INCREMENTAL_BACKUP_DIR" "$WAL_ARCHIVE_DIR"

# Función de logging
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Función para limpiar respaldos antiguos
limpiar_respaldos_antiguos() {
    log "Iniciando limpieza de respaldos antiguos (retención: $RETENTION_DAYS días)"
    
    # Limpiar backups completos antiguos
    find "$FULL_BACKUP_DIR" -type f -name "*.tar.gz" -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
    
    # Limpiar backups incrementales antiguos
    find "$INCREMENTAL_BACKUP_DIR" -type f -name "*.tar.gz" -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
    
    # Limpiar archivos WAL antiguos (mantener últimos 3 días para recovery)
    find "$WAL_ARCHIVE_DIR" -type f -name "0*" -mtime +3 -delete 2>/dev/null || true
    
    log "Limpieza de respaldos completada"
}

# Función para realizar backup completo
backup_completo() {
    local fecha=$(date '+%Y%m%d_%H%M%S')
    local backup_file="$FULL_BACKUP_DIR/full_backup_$fecha.tar.gz"
    
    log "=== INICIANDO BACKUP COMPLETO ==="
    log "Archivo de destino: $backup_file"
    
    # Verificar que el primario esté disponible
    if ! docker exec postgresql-primary pg_isready -U admin -d proyecto_db >/dev/null 2>&1; then
        log "ERROR: El nodo primario no está disponible"
        return 1
    fi
    
    # Realizar pg_basebackup
    log "Ejecutando pg_basebackup..."
    docker exec postgresql-primary bash -c "
        PGPASSWORD=admin123 pg_basebackup \
            -h localhost \
            -D /tmp/backup_$fecha \
            -U admin \
            -v \
            -P \
            -W \
            -F tar \
            -z \
            -Z 6
        
        # Mover el archivo al directorio de backups
        mv /tmp/backup_$fecha.tar.gz $backup_file
        
        # Limpiar directorio temporal
        rm -rf /tmp/backup_$fecha
    "
    
    if [ $? -eq 0 ]; then
        local size=$(docker exec postgresql-primary ls -lh "$backup_file" | awk '{print $5}')
        log "✅ BACKUP COMPLETO EXITOSO - Tamaño: $size"
        
        # Registrar en la base de datos
        docker exec postgresql-primary psql -U admin -d proyecto_db -c "
            INSERT INTO proyecto.logs_replicacion (nodo, evento) 
            VALUES ('backup', 'Backup completo realizado: $backup_file');
        " >/dev/null 2>&1
        
    else
        log "❌ ERROR: Falló el backup completo"
        return 1
    fi
}

# Función para realizar backup incremental
backup_incremental() {
    local fecha=$(date '+%Y%m%d_%H%M%S')
    local backup_file="$INCREMENTAL_BACKUP_DIR/incremental_backup_$fecha.tar.gz"
    
    log "=== INICIANDO BACKUP INCREMENTAL ==="
    log "Archivo de destino: $backup_file"
    
    # Verificar que el primario esté disponible
    if ! docker exec postgresql-primary pg_isready -U admin -d proyecto_db >/dev/null 2>&1; then
        log "ERROR: El nodo primario no está disponible"
        return 1
    fi
    
    # Crear backup incremental basado en archivos WAL
    log "Creando backup incremental de archivos WAL..."
    docker exec postgresql-primary bash -c "
        cd $WAL_ARCHIVE_DIR
        
        # Encontrar archivos WAL de las últimas 24 horas
        find . -type f -name '0*' -mtime -1 > /tmp/wal_files_$fecha.list
        
        if [ -s /tmp/wal_files_$fecha.list ]; then
            # Crear tar con archivos WAL recientes
            tar -czf $backup_file -T /tmp/wal_files_$fecha.list
            echo 'Backup incremental creado exitosamente'
        else
            echo 'No hay archivos WAL nuevos para respaldar'
            touch $backup_file
        fi
        
        # Limpiar archivo temporal
        rm -f /tmp/wal_files_$fecha.list
    "
    
    if [ $? -eq 0 ]; then
        local size=$(docker exec postgresql-primary ls -lh "$backup_file" 2>/dev/null | awk '{print $5}' || echo "0B")
        log "✅ BACKUP INCREMENTAL EXITOSO - Tamaño: $size"
        
        # Registrar en la base de datos
        docker exec postgresql-primary psql -U admin -d proyecto_db -c "
            INSERT INTO proyecto.logs_replicacion (nodo, evento) 
            VALUES ('backup', 'Backup incremental realizado: $backup_file');
        " >/dev/null 2>&1
        
    else
        log "❌ ERROR: Falló el backup incremental"
        return 1
    fi
}

# Función para mostrar estado de respaldos
mostrar_estado_respaldos() {
    log "=== ESTADO DE RESPALDOS ==="
    
    echo ""
    echo "📁 Backups completos disponibles:"
    docker exec postgresql-primary ls -lh "$FULL_BACKUP_DIR"/*.tar.gz 2>/dev/null || echo "No hay backups completos"
    
    echo ""
    echo "📁 Backups incrementales disponibles:"
    docker exec postgresql-primary ls -lh "$INCREMENTAL_BACKUP_DIR"/*.tar.gz 2>/dev/null || echo "No hay backups incrementales"
    
    echo ""
    echo "📁 Archivos WAL disponibles:"
    docker exec postgresql-primary find "$WAL_ARCHIVE_DIR" -name "0*" | wc -l || echo "0"
    
    echo ""
    echo "💾 Uso de espacio en /backups:"
    docker exec postgresql-primary du -sh "$BACKUP_DIR"/* 2>/dev/null || echo "Directorio vacío"
}

# Función para verificar integridad de respaldos
verificar_integridad() {
    log "=== VERIFICACIÓN DE INTEGRIDAD DE RESPALDOS ==="
    
    local errores=0
    
    # Verificar backups completos
    for archivo in $(docker exec postgresql-primary find "$FULL_BACKUP_DIR" -name "*.tar.gz" 2>/dev/null); do
        if docker exec postgresql-primary tar -tzf "$archivo" >/dev/null 2>&1; then
            log "✅ OK: $archivo"
        else
            log "❌ CORRUPTO: $archivo"
            errores=$((errores + 1))
        fi
    done
    
    # Verificar backups incrementales
    for archivo in $(docker exec postgresql-primary find "$INCREMENTAL_BACKUP_DIR" -name "*.tar.gz" 2>/dev/null); do
        if docker exec postgresql-primary tar -tzf "$archivo" >/dev/null 2>&1; then
            log "✅ OK: $archivo"
        else
            log "❌ CORRUPTO: $archivo"
            errores=$((errores + 1))
        fi
    done
    
    if [ $errores -eq 0 ]; then
        log "✅ VERIFICACIÓN COMPLETADA: Todos los respaldos están íntegros"
    else
        log "⚠️  ADVERTENCIA: $errores respaldos presentan errores"
    fi
}

# Menú principal
case "${1:-menu}" in
    "completo")
        backup_completo
        limpiar_respaldos_antiguos
        ;;
    "incremental")
        backup_incremental
        limpiar_respaldos_antiguos
        ;;
    "estado")
        mostrar_estado_respaldos
        ;;
    "verificar")
        verificar_integridad
        ;;
    "limpiar")
        limpiar_respaldos_antiguos
        ;;
    "menu"|*)
        echo "==========================================="
        echo "  SCRIPT DE RESPALDOS POSTGRESQL"
        echo "==========================================="
        echo ""
        echo "Uso: $0 [opción]"
        echo ""
        echo "Opciones disponibles:"
        echo "  completo      - Realizar backup completo semanal"
        echo "  incremental   - Realizar backup incremental diario"
        echo "  estado        - Mostrar estado de respaldos"
        echo "  verificar     - Verificar integridad de respaldos"
        echo "  limpiar       - Limpiar respaldos antiguos"
        echo ""
        echo "Ejemplos:"
        echo "  $0 completo"
        echo "  $0 incremental"
        echo "  $0 estado"
        echo ""
        echo "Política de respaldos:"
        echo "  - Backup completo: Semanal (domingos)"
        echo "  - Backup incremental: Diario"
        echo "  - Retención: $RETENTION_DAYS días"
        echo ""
        
        # Mostrar estado actual
        mostrar_estado_respaldos
        ;;
esac

log "Script de respaldos finalizado"