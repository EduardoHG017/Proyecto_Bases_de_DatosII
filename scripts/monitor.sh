#!/bin/bash
# ===================================================================
# SCRIPT DE MONITOREO DE REPLICACIÓN
# ===================================================================
# Script para monitorear el estado de la replicación entre nodos
# Uso: ./monitor.sh

set -e

# Función para mostrar encabezado
mostrar_encabezado() {
    clear
    echo "==========================================="
    echo "  MONITOR DE REPLICACIÓN POSTGRESQL"
    echo "==========================================="
    echo "Fecha: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
}

# Función para verificar estado de contenedores
verificar_contenedores() {
    echo "📦 ESTADO DE CONTENEDORES:"
    echo "----------------------------------------"
    
    for contenedor in postgresql-primary postgresql-standby postgresql-readonly; do
        if docker ps --format "table {{.Names}}\t{{.Status}}" | grep -q "$contenedor"; then
            status=$(docker ps --format "table {{.Names}}\t{{.Status}}" | grep "$contenedor" | awk '{$1=""; print $0}' | sed 's/^ *//')
            echo "✅ $contenedor: $status"
        else
            echo "❌ $contenedor: No está ejecutándose"
        fi
    done
    echo ""
}

# Función para mostrar estado de replicación desde el primario
estado_replicacion_primario() {
    echo "🔄 ESTADO DE REPLICACIÓN (desde primario):"
    echo "----------------------------------------"
    
    if docker exec postgresql-primary pg_isready -U admin -d proyecto_db >/dev/null 2>&1; then
        docker exec postgresql-primary psql -U admin -d proyecto_db -c "
            SELECT 
                application_name,
                client_addr,
                state,
                sent_lsn,
                write_lsn,
                flush_lsn,
                replay_lsn,
                write_lag,
                flush_lag,
                replay_lag
            FROM pg_stat_replication;
        " 2>/dev/null || echo "No hay conexiones de replicación activas"
    else
        echo "❌ El nodo primario no está disponible"
    fi
    echo ""
}

# Función para mostrar estado de cada nodo
estado_nodos() {
    echo "🏥 ESTADO DE CADA NODO:"
    echo "----------------------------------------"
    
    # Nodo primario
    echo "📍 NODO PRIMARIO (puerto 5432):"
    if docker exec postgresql-primary pg_isready -U admin -d proyecto_db >/dev/null 2>&1; then
        recovery_status=$(docker exec postgresql-primary psql -U admin -d proyecto_db -t -c "SELECT pg_is_in_recovery();" 2>/dev/null | tr -d ' ')
        if [[ "$recovery_status" == "f" ]]; then
            echo "  ✅ Estado: PRIMARIO (acepta escrituras)"
            lsn=$(docker exec postgresql-primary psql -U admin -d proyecto_db -t -c "SELECT pg_current_wal_lsn();" 2>/dev/null | tr -d ' ')
            echo "  📊 LSN actual: $lsn"
        else
            echo "  ⚠️  Estado: EN RECOVERY (no es primario)"
        fi
    else
        echo "  ❌ No disponible"
    fi
    
    # Nodo standby
    echo ""
    echo "📍 NODO STANDBY (puerto 5433):"
    if docker exec postgresql-standby pg_isready -U admin -d proyecto_db >/dev/null 2>&1; then
        recovery_status=$(docker exec postgresql-standby psql -U admin -d proyecto_db -t -c "SELECT pg_is_in_recovery();" 2>/dev/null | tr -d ' ')
        if [[ "$recovery_status" == "t" ]]; then
            echo "  ✅ Estado: STANDBY (en replicación)"
            last_replay=$(docker exec postgresql-standby psql -U admin -d proyecto_db -t -c "SELECT pg_last_wal_replay_lsn();" 2>/dev/null | tr -d ' ')
            echo "  📊 Último LSN replicado: $last_replay"
        else
            echo "  ⚠️  Estado: PROMOVIDO A PRIMARIO"
        fi
    else
        echo "  ❌ No disponible"
    fi
    
    # Nodo readonly
    echo ""
    echo "📍 NODO READONLY (puerto 5434):"
    if docker exec postgresql-readonly pg_isready -U admin -d proyecto_db >/dev/null 2>&1; then
        recovery_status=$(docker exec postgresql-readonly psql -U admin -d proyecto_db -t -c "SELECT pg_is_in_recovery();" 2>/dev/null | tr -d ' ')
        if [[ "$recovery_status" == "t" ]]; then
            echo "  ✅ Estado: READONLY (en replicación)"
            last_replay=$(docker exec postgresql-readonly psql -U admin -d proyecto_db -t -c "SELECT pg_last_wal_replay_lsn();" 2>/dev/null | tr -d ' ')
            echo "  📊 Último LSN replicado: $last_replay"
        else
            echo "  ⚠️  Estado: NO EN RECOVERY"
        fi
    else
        echo "  ❌ No disponible"
    fi
    echo ""
}

# Función para mostrar estadísticas de la base de datos
estadisticas_bd() {
    echo "📊 ESTADÍSTICAS DE BASE DE DATOS:"
    echo "----------------------------------------"
    
    if docker exec postgresql-primary pg_isready -U admin -d proyecto_db >/dev/null 2>&1; then
        echo "Desde el nodo primario:"
        docker exec postgresql-primary psql -U admin -d proyecto_db -c "
            SELECT 
                schemaname,
                tablename,
                n_tup_ins as insertados,
                n_tup_upd as actualizados,
                n_tup_del as eliminados,
                n_live_tup as filas_activas
            FROM pg_stat_user_tables 
            WHERE schemaname = 'proyecto';
        " 2>/dev/null
        
        echo ""
        echo "Últimos eventos de replicación:"
        docker exec postgresql-primary psql -U admin -d proyecto_db -c "
            SELECT * FROM proyecto.logs_replicacion 
            ORDER BY timestamp DESC 
            LIMIT 5;
        " 2>/dev/null
    else
        echo "❌ No se pueden obtener estadísticas (primario no disponible)"
    fi
    echo ""
}

# Función para prueba de conectividad
prueba_conectividad() {
    echo "🔗 PRUEBA DE CONECTIVIDAD:"
    echo "----------------------------------------"
    
    echo "Probando conexión a cada nodo:"
    
    # Probar primario
    if docker exec postgresql-primary psql -U admin -d proyecto_db -c "SELECT 'Primario conectado' as status;" >/dev/null 2>&1; then
        echo "✅ Primario (5432): Conectado"
    else
        echo "❌ Primario (5432): Error de conexión"
    fi
    
    # Probar standby
    if docker exec postgresql-standby psql -U admin -d proyecto_db -c "SELECT 'Standby conectado' as status;" >/dev/null 2>&1; then
        echo "✅ Standby (5433): Conectado"
    else
        echo "❌ Standby (5433): Error de conexión"
    fi
    
    # Probar readonly
    if docker exec postgresql-readonly psql -U admin -d proyecto_db -c "SELECT 'Readonly conectado' as status;" >/dev/null 2>&1; then
        echo "✅ Readonly (5434): Conectado"
    else
        echo "❌ Readonly (5434): Error de conexión"
    fi
    echo ""
}

# Función para monitoreo continuo
monitoreo_continuo() {
    echo "Iniciando monitoreo continuo (presione Ctrl+C para salir)..."
    echo ""
    
    while true; do
        mostrar_encabezado
        verificar_contenedores
        estado_nodos
        estado_replicacion_primario
        
        echo "⏱️  Actualizando en 10 segundos..."
        sleep 10
    done
}

# Función para generar reporte completo
generar_reporte() {
    local archivo_reporte="/backups/reporte_replicacion_$(date +%Y%m%d_%H%M%S).txt"
    
    echo "Generando reporte completo..."
    {
        echo "REPORTE DE REPLICACIÓN POSTGRESQL"
        echo "=================================="
        echo "Fecha: $(date)"
        echo ""
        
        echo "ESTADO DE CONTENEDORES:"
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep postgresql
        echo ""
        
        echo "ESTADO DE REPLICACIÓN:"
        docker exec postgresql-primary psql -U admin -d proyecto_db -c "SELECT * FROM pg_stat_replication;" 2>/dev/null || echo "Primario no disponible"
        echo ""
        
        echo "LOGS RECIENTES:"
        docker exec postgresql-primary psql -U admin -d proyecto_db -c "SELECT * FROM proyecto.logs_replicacion ORDER BY timestamp DESC LIMIT 10;" 2>/dev/null || echo "No disponible"
        
    } > "reporte_$(date +%Y%m%d_%H%M%S).txt"
    
    echo "✅ Reporte generado: reporte_$(date +%Y%m%d_%H%M%S).txt"
}

# Menú principal
case "${1:-menu}" in
    "continuo")
        monitoreo_continuo
        ;;
    "reporte")
        generar_reporte
        ;;
    "estado")
        mostrar_encabezado
        verificar_contenedores
        estado_nodos
        estado_replicacion_primario
        ;;
    "estadisticas")
        mostrar_encabezado
        estadisticas_bd
        ;;
    "conectividad")
        mostrar_encabezado
        prueba_conectividad
        ;;
    "menu"|*)
        mostrar_encabezado
        echo "Uso: $0 [opción]"
        echo ""
        echo "Opciones disponibles:"
        echo "  estado        - Mostrar estado actual de la replicación"
        echo "  continuo      - Monitoreo continuo en tiempo real"
        echo "  estadisticas  - Mostrar estadísticas de la base de datos"
        echo "  conectividad  - Probar conectividad a todos los nodos"
        echo "  reporte       - Generar reporte completo"
        echo ""
        echo "Ejemplos:"
        echo "  $0 estado"
        echo "  $0 continuo"
        echo "  $0 reporte"
        echo ""
        
        # Mostrar resumen rápido
        verificar_contenedores
        ;;
esac