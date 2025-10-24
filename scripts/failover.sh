#!/bin/bash
# ===================================================================
# SCRIPT DE FAILOVER MANUAL
# ===================================================================
# Script para simular la caída del nodo primario y promover el standby
# Uso: ./failover.sh

set -e

echo "==========================================="
echo "  SCRIPT DE FAILOVER MANUAL POSTGRESQL"
echo "==========================================="

# Función para mostrar el estado de replicación
mostrar_estado() {
    echo ""
    echo "--- Estado actual de la replicación ---"
    docker exec postgresql-primary psql -U admin -d proyecto_db -c "SELECT * FROM pg_stat_replication;" 2>/dev/null || echo "Primario no disponible"
    
    echo ""
    echo "--- Estado del standby ---"
    docker exec postgresql-standby psql -U admin -d proyecto_db -c "SELECT pg_is_in_recovery();" 2>/dev/null || echo "Standby no disponible"
}

# Función para promover standby
promover_standby() {
    echo ""
    echo "=== PROMOCIÓN DEL NODO STANDBY A PRIMARIO ==="
    
    # Promover el standby a primario
    echo "Ejecutando promoción..."
    docker exec postgresql-standby pg_ctl promote -D /var/lib/postgresql/data
    
    sleep 5
    
    # Verificar que la promoción fue exitosa
    echo "Verificando promoción..."
    RECOVERY_STATUS=$(docker exec postgresql-standby psql -U admin -d proyecto_db -t -c "SELECT pg_is_in_recovery();")
    
    if [[ "$RECOVERY_STATUS" == *"f"* ]]; then
        echo "✅ PROMOCIÓN EXITOSA: El nodo standby ahora es el primario"
        
        # Insertar registro de failover
        docker exec postgresql-standby psql -U admin -d proyecto_db -c "
            INSERT INTO proyecto.logs_replicacion (nodo, evento) 
            VALUES ('standby->primary', 'Failover ejecutado - Standby promovido a primario');
        "
        
        echo ""
        echo "📊 Verificando funcionamiento del nuevo primario:"
        docker exec postgresql-standby psql -U admin -d proyecto_db -c "
            INSERT INTO proyecto.usuarios (nombre, email) 
            VALUES ('Test Failover', 'test.failover@email.com');
            SELECT 'Escritura exitosa en nuevo primario' as status;
        "
        
    else
        echo "❌ ERROR: La promoción falló"
        exit 1
    fi
}

# Función para simular caída del primario
simular_caida_primario() {
    echo ""
    echo "=== SIMULANDO CAÍDA DEL NODO PRIMARIO ==="
    echo "Deteniendo contenedor postgresql-primary..."
    docker stop postgresql-primary
    echo "✅ Nodo primario detenido"
    
    sleep 3
    
    echo ""
    echo "⏳ Esperando detección de falla por parte del standby..."
    sleep 10
}

# Función para restaurar configuración original
restaurar_configuracion() {
    echo ""
    echo "=== RESTAURANDO CONFIGURACIÓN ORIGINAL ==="
    
    read -p "¿Desea restaurar la configuración original? (y/N): " confirmar
    if [[ $confirmar =~ ^[Yy]$ ]]; then
        echo "Reiniciando todos los contenedores..."
        docker-compose down
        echo "Eliminando volúmenes para empezar limpio..."
        docker volume rm proyecto_postgresql_postgresql-primary-data proyecto_postgresql_postgresql-standby-data 2>/dev/null || true
        echo "Levantando configuración original..."
        docker-compose up -d
        echo "✅ Configuración original restaurada"
    fi
}

# Menú principal
echo ""
echo "Seleccione una opción:"
echo "1) Mostrar estado actual"
echo "2) Simular caída del primario + Failover automático"
echo "3) Solo promover standby (sin detener primario)"
echo "4) Restaurar configuración original"
echo "5) Salir"
echo ""

read -p "Ingrese su opción (1-5): " opcion

case $opcion in
    1)
        mostrar_estado
        ;;
    2)
        echo ""
        echo "⚠️  ATENCIÓN: Esta operación detendrá el nodo primario"
        read -p "¿Está seguro de continuar? (y/N): " confirmar
        if [[ $confirmar =~ ^[Yy]$ ]]; then
            mostrar_estado
            simular_caida_primario
            promover_standby
            echo ""
            echo "🎉 FAILOVER COMPLETADO"
            echo "El nuevo primario está en el puerto 5433"
            echo "Ejecute 'docker logs postgresql-standby' para ver los logs"
        else
            echo "Operación cancelada"
        fi
        ;;
    3)
        echo ""
        echo "⚠️  ATENCIÓN: Esto promoverá el standby sin detener el primario"
        echo "Esto creará una situación de split-brain"
        read -p "¿Está seguro de continuar? (y/N): " confirmar
        if [[ $confirmar =~ ^[Yy]$ ]]; then
            promover_standby
        else
            echo "Operación cancelada"
        fi
        ;;
    4)
        restaurar_configuracion
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
echo "Script de failover completado."