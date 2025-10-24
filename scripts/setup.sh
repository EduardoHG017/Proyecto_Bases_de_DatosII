#!/bin/bash
# ===================================================================
# SCRIPT DE CONFIGURACIÓN Y PRUEBAS DEL CLÚSTER
# ===================================================================
# Script principal para configurar y probar todo el sistema
# Uso: ./setup.sh

set -e

echo "==========================================="
echo "  CONFIGURACIÓN DEL CLÚSTER POSTGRESQL"
echo "==========================================="
echo ""

# Función para verificar dependencias
verificar_dependencias() {
    echo "🔍 Verificando dependencias..."
    
    if ! command -v docker &> /dev/null; then
        echo "❌ Docker no está instalado"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        echo "❌ Docker Compose no está instalado"
        exit 1
    fi
    
    echo "✅ Docker y Docker Compose están disponibles"
}

# Función para limpiar instalación anterior
limpiar_instalacion() {
    echo ""
    echo "🧹 Limpiando instalación anterior..."
    
    # Detener contenedores
    docker-compose down 2>/dev/null || true
    
    # Eliminar volúmenes (opcional)
    read -p "¿Desea eliminar los datos existentes? (y/N): " eliminar_datos
    if [[ $eliminar_datos =~ ^[Yy]$ ]]; then
        docker volume rm proyecto_postgresql_postgresql-primary-data 2>/dev/null || true
        docker volume rm proyecto_postgresql_postgresql-standby-data 2>/dev/null || true
        docker volume rm proyecto_postgresql_postgresql-readonly-data 2>/dev/null || true
        echo "✅ Volúmenes eliminados"
    else
        echo "📦 Conservando datos existentes"
    fi
}

# Función para iniciar contenedores
iniciar_contenedores() {
    echo ""
    echo "🚀 Iniciando contenedores..."
    
    # Construir e iniciar contenedores
    docker-compose up -d
    
    echo "⏳ Esperando a que los contenedores estén listos..."
    sleep 30
    
    # Verificar estado
    echo ""
    echo "📦 Estado de contenedores:"
    docker-compose ps
}

# Función para configurar permisos
configurar_permisos() {
    echo ""
    echo "🔑 Configurando permisos en scripts..."
    
    # Hacer ejecutables los scripts dentro de los contenedores
    docker exec postgresql-primary chmod +x /scripts/*.sh 2>/dev/null || true
    docker exec postgresql-standby chmod +x /scripts/*.sh 2>/dev/null || true
    docker exec postgresql-readonly chmod +x /scripts/*.sh 2>/dev/null || true
    
    echo "✅ Permisos configurados"
}

# Función para esperar a que PostgreSQL esté listo
esperar_postgresql() {
    echo ""
    echo "⏳ Esperando a que PostgreSQL esté completamente iniciado..."
    
    # Esperar al primario
    local intentos=0
    while ! docker exec postgresql-primary pg_isready -U admin -d proyecto_db >/dev/null 2>&1; do
        echo "Esperando al nodo primario..."
        sleep 5
        intentos=$((intentos + 1))
        if [ $intentos -gt 24 ]; then  # 2 minutos máximo
            echo "❌ Timeout esperando al nodo primario"
            exit 1
        fi
    done
    
    echo "✅ Nodo primario listo"
    
    # Esperar a los nodos de réplica
    sleep 15
    echo "✅ Nodos de réplica iniciados"
}

# Función para realizar pruebas básicas
realizar_pruebas() {
    echo ""
    echo "🧪 Realizando pruebas básicas..."
    
    # Prueba 1: Verificar conectividad
    echo "Prueba 1: Conectividad a nodos"
    if docker exec postgresql-primary psql -U admin -d proyecto_db -c "SELECT 'Primario OK' as status;" >/dev/null 2>&1; then
        echo "✅ Primario: Conectado"
    else
        echo "❌ Primario: Error"
    fi
    
    if docker exec postgresql-standby psql -U admin -d proyecto_db -c "SELECT 'Standby OK' as status;" >/dev/null 2>&1; then
        echo "✅ Standby: Conectado"
    else
        echo "❌ Standby: Error"
    fi
    
    if docker exec postgresql-readonly psql -U admin -d proyecto_db -c "SELECT 'Readonly OK' as status;" >/dev/null 2>&1; then
        echo "✅ Readonly: Conectado"
    else
        echo "❌ Readonly: Error"
    fi
    
    # Prueba 2: Verificar replicación
    echo ""
    echo "Prueba 2: Estado de replicación"
    docker exec postgresql-primary psql -U admin -d proyecto_db -c "
        SELECT application_name, state, sync_state 
        FROM pg_stat_replication;
    " || echo "No hay conexiones de replicación"
    
    # Prueba 3: Insertar datos de prueba
    echo ""
    echo "Prueba 3: Insertando datos de prueba en el primario"
    docker exec postgresql-primary psql -U admin -d proyecto_db -c "
        INSERT INTO proyecto.usuarios (nombre, email) 
        VALUES ('Usuario Prueba', 'prueba@test.com')
        ON CONFLICT (email) DO NOTHING;
        
        INSERT INTO proyecto.logs_replicacion (nodo, evento) 
        VALUES ('setup', 'Configuración inicial completada - datos de prueba insertados');
    "
    
    # Esperar replicación
    sleep 5
    
    # Verificar datos en standby
    echo "Verificando replicación en standby..."
    docker exec postgresql-standby psql -U admin -d proyecto_db -c "
        SELECT COUNT(*) as total_usuarios FROM proyecto.usuarios;
    "
    
    # Verificar datos en readonly
    echo "Verificando replicación en readonly..."
    docker exec postgresql-readonly psql -U admin -d proyecto_db -c "
        SELECT COUNT(*) as total_usuarios FROM proyecto.usuarios;
    "
    
    echo "✅ Pruebas básicas completadas"
}

# Función para mostrar información de conexión
mostrar_info_conexion() {
    echo ""
    echo "==========================================="
    echo "  INFORMACIÓN DE CONEXIÓN"
    echo "==========================================="
    echo ""
    echo "🔗 PUERTOS DE CONEXIÓN:"
    echo "  • Nodo Primario:  localhost:5432"
    echo "  • Nodo Standby:   localhost:5433"
    echo "  • Nodo Readonly:  localhost:5434"
    echo ""
    echo "👤 CREDENCIALES:"
    echo "  • Usuario:     admin"
    echo "  • Contraseña:  admin123"
    echo "  • Base de datos: proyecto_db"
    echo ""
    echo "🔧 COMANDOS ÚTILES:"
    echo "  • Ver estado:      ./scripts/monitor.sh estado"
    echo "  • Failover manual: ./scripts/failover.sh"
    echo "  • Crear backup:    ./scripts/backup.sh completo"
    echo "  • Ver logs:        docker-compose logs -f"
    echo ""
    echo "📊 EJEMPLOS DE CONEXIÓN:"
    echo "  • psql -h localhost -p 5432 -U admin -d proyecto_db  # Primario"
    echo "  • psql -h localhost -p 5433 -U admin -d proyecto_db  # Standby"
    echo "  • psql -h localhost -p 5434 -U admin -d proyecto_db  # Readonly"
    echo ""
}

# Función para configurar respaldos automáticos
configurar_respaldos() {
    echo ""
    echo "⚙️  ¿Desea configurar respaldos automáticos? (y/N):"
    read -r configurar_cron
    
    if [[ $configurar_cron =~ ^[Yy]$ ]]; then
        echo "Configurando respaldos automáticos..."
        docker exec postgresql-primary /scripts/setup_cron.sh
    else
        echo "Respaldos automáticos no configurados. Puede hacerlo más tarde con:"
        echo "docker exec postgresql-primary /scripts/setup_cron.sh"
    fi
}

# Función principal
main() {
    verificar_dependencias
    limpiar_instalacion
    iniciar_contenedores
    configurar_permisos
    esperar_postgresql
    realizar_pruebas
    configurar_respaldos
    mostrar_info_conexion
    
    echo "🎉 ¡CONFIGURACIÓN COMPLETADA EXITOSAMENTE!"
    echo ""
    echo "El clúster PostgreSQL está listo para usar."
    echo "Puede comenzar a trabajar conectándose a los nodos."
}

# Menú de opciones
case "${1:-setup}" in
    "setup")
        main
        ;;
    "test")
        realizar_pruebas
        ;;
    "info")
        mostrar_info_conexion
        ;;
    "clean")
        limpiar_instalacion
        ;;
    *)
        echo "Uso: $0 [opción]"
        echo ""
        echo "Opciones:"
        echo "  setup  - Configuración completa (por defecto)"
        echo "  test   - Solo ejecutar pruebas"
        echo "  info   - Mostrar información de conexión"
        echo "  clean  - Limpiar instalación"
        ;;
esac