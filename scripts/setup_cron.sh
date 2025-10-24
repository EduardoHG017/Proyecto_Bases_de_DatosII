#!/bin/bash
# ===================================================================
# SCRIPT DE CONFIGURACIÓN DE CRONTAB PARA RESPALDOS AUTOMÁTICOS
# ===================================================================
# Este script configura los respaldos automáticos usando crontab
# Política: Backup completo los domingos, incremental diarios

set -e

SCRIPT_DIR="/scripts"
CRON_FILE="/tmp/postgresql_backup_cron"

echo "==========================================="
echo "  CONFIGURACIÓN DE RESPALDOS AUTOMÁTICOS"
echo "==========================================="

# Verificar que el script de backup existe
if [ ! -f "$SCRIPT_DIR/backup.sh" ]; then
    echo "❌ ERROR: No se encuentra el script backup.sh en $SCRIPT_DIR"
    exit 1
fi

# Hacer ejecutables los scripts
chmod +x "$SCRIPT_DIR/backup.sh"
chmod +x "$SCRIPT_DIR/monitor.sh"
chmod +x "$SCRIPT_DIR/failover.sh"

echo "✅ Scripts marcados como ejecutables"

# Crear archivo de crontab
cat > "$CRON_FILE" << 'EOF'
# Respaldos automáticos PostgreSQL
# Proyecto de Base de Datos II

# Backup completo los domingos a las 2:00 AM
0 2 * * 0 /scripts/backup.sh completo >> /backups/cron.log 2>&1

# Backup incremental todos los días a las 1:00 AM (excepto domingos)
0 1 * * 1-6 /scripts/backup.sh incremental >> /backups/cron.log 2>&1

# Verificación de integridad los miércoles a las 3:00 AM
0 3 * * 3 /scripts/backup.sh verificar >> /backups/cron.log 2>&1

# Limpieza de respaldos antiguos todos los días a las 4:00 AM
0 4 * * * /scripts/backup.sh limpiar >> /backups/cron.log 2>&1

# Monitoreo cada 15 minutos (solo genera log si hay problemas)
*/15 * * * * /scripts/monitor.sh estado | grep -E "(❌|⚠️)" >> /backups/monitor.log 2>&1 || true

EOF

echo ""
echo "📋 CONFIGURACIÓN DE CRONTAB CREADA:"
echo "------------------------------------"
cat "$CRON_FILE"

echo ""
echo "🔧 INSTRUCCIONES PARA ACTIVAR:"
echo "------------------------------"
echo "1. Para instalar en el contenedor primario:"
echo "   docker exec postgresql-primary crontab $CRON_FILE"
echo ""
echo "2. Para verificar que se instaló:"
echo "   docker exec postgresql-primary crontab -l"
echo ""
echo "3. Para ver logs de cron:"
echo "   docker exec postgresql-primary tail -f /backups/cron.log"
echo ""

# Función para instalar automáticamente
instalar_crontab() {
    echo "¿Desea instalar automáticamente el crontab en el contenedor primario? (y/N):"
    read -r respuesta
    
    if [[ $respuesta =~ ^[Yy]$ ]]; then
        echo "Instalando crontab..."
        
        # Verificar que el contenedor esté ejecutándose
        if docker ps | grep -q postgresql-primary; then
            # Instalar crontab
            docker exec postgresql-primary crontab "$CRON_FILE"
            
            # Verificar instalación
            echo ""
            echo "✅ Crontab instalado. Configuración actual:"
            docker exec postgresql-primary crontab -l
            
            echo ""
            echo "📊 Próximas ejecuciones programadas:"
            echo "- Backup incremental: Diario a la 1:00 AM (Lun-Sáb)"
            echo "- Backup completo: Domingos a las 2:00 AM"
            echo "- Verificación: Miércoles a las 3:00 AM"
            echo "- Limpieza: Diario a las 4:00 AM"
            echo "- Monitoreo: Cada 15 minutos"
            
        else
            echo "❌ ERROR: El contenedor postgresql-primary no está ejecutándose"
            echo "Inicie los contenedores con: docker-compose up -d"
        fi
    else
        echo "Instalación cancelada. Puede instalar manualmente más tarde."
    fi
}

# Crear script de prueba para verificar que todo funciona
crear_script_prueba() {
    cat > "$SCRIPT_DIR/test_backups.sh" << 'EOF'
#!/bin/bash
# Script de prueba para verificar el sistema de respaldos

echo "=== PRUEBA DEL SISTEMA DE RESPALDOS ==="

echo "1. Probando backup incremental..."
/scripts/backup.sh incremental

echo ""
echo "2. Verificando estado de respaldos..."
/scripts/backup.sh estado

echo ""
echo "3. Verificando integridad..."
/scripts/backup.sh verificar

echo ""
echo "4. Probando monitoreo..."
/scripts/monitor.sh estado

echo ""
echo "✅ Prueba completada"
EOF

    chmod +x "$SCRIPT_DIR/test_backups.sh"
    echo "✅ Script de prueba creado: $SCRIPT_DIR/test_backups.sh"
}

# Crear archivo de configuración para variables de entorno
crear_config_env() {
    cat > "$SCRIPT_DIR/backup.conf" << 'EOF'
# Configuración para scripts de backup
# Este archivo puede ser sourced por los scripts

POSTGRES_HOST="localhost"
POSTGRES_PORT="5432"
POSTGRES_USER="admin"
POSTGRES_DB="proyecto_db"
BACKUP_RETENTION_DAYS=7
BACKUP_COMPRESSION_LEVEL=6
MONITOR_LOG_LEVEL="INFO"

# Configuración de notificaciones (opcional)
ENABLE_EMAIL_NOTIFICATIONS=false
ADMIN_EMAIL=""

# Configuración de almacenamiento
BACKUP_REMOTE_SYNC=false
REMOTE_BACKUP_PATH=""
EOF

    echo "✅ Archivo de configuración creado: $SCRIPT_DIR/backup.conf"
}

# Ejecutar funciones
crear_script_prueba
crear_config_env

echo ""
echo "🎯 SIGUIENTE PASO:"
instalar_crontab

echo ""
echo "📚 COMANDOS ÚTILES:"
echo "-------------------"
echo "• Ejecutar backup manual: docker exec postgresql-primary /scripts/backup.sh completo"
echo "• Ver estado: docker exec postgresql-primary /scripts/monitor.sh estado"
echo "• Probar sistema: docker exec postgresql-primary /scripts/test_backups.sh"
echo "• Ver logs de cron: docker exec postgresql-primary tail -f /backups/cron.log"
echo ""
echo "✅ Configuración de respaldos automáticos completada"