# Guía Paso-a-Paso: Levantar y Verificar Clúster PostgreSQL en Windows

## 📋 Prerrequisitos
Antes de empezar, verifica que tienes instalado:

```powershell
# Verificar Docker Desktop
docker --version
docker-compose --version

# Verificar PowerShell (debería ser 5.1 o superior)
$PSVersionTable.PSVersion
```

**Requisitos:**
- Docker Desktop for Windows (funcionando)
- PowerShell 5.1+ 
- Git (opcional, para clonar)
- ~2GB de espacio libre en disco

## 🚀 Paso 1: Preparar el Entorno

### 1.1 Abrir PowerShell como Administrador
```powershell
# Verificar que Docker está corriendo
docker ps
# Debería mostrar la lista de contenedores (puede estar vacía)
```

### 1.2 Navegar al Directorio del Proyecto
```powershell
# Cambiar al directorio del proyecto
cd "c:\Users\edugu\OneDrive\Desktop\Guayo\Proyecto_Bases_De_Datos_II\proyecto_postgresql"

# Verificar que estás en el directorio correcto
ls
# Deberías ver: docker-compose.yml, primary/, standby/, readonly/, scripts/, etc.
```

### 1.3 Limpiar Instalación Anterior (si existe)
```powershell
# Detener contenedores existentes
docker-compose down

# Opcional: Eliminar volúmenes antiguos para empezar limpio
docker volume ls | findstr "proyecto_postgresql"
docker volume rm proyecto_postgresql_postgresql-primary-data -f
docker volume rm proyecto_postgresql_postgresql-standby-data -f  
docker volume rm proyecto_postgresql_postgresql-readonly-data -f
```

## 🏗️ Paso 2: Levantar el Nodo Primario

### 2.1 Iniciar el Contenedor Primario
```powershell
# Levantar solo el nodo primario
docker-compose up -d

# Verificar que el contenedor está corriendo
docker-compose ps
# Debería mostrar postgresql-primary como "Up"
```

### 2.2 Esperar a que PostgreSQL esté Listo
```powershell
# Esperar hasta que PostgreSQL esté completamente iniciado
do {
    Write-Host "Esperando a que PostgreSQL esté listo..."
    Start-Sleep -Seconds 5
    $ready = docker exec postgresql-primary pg_isready -U admin -d proyecto_db 2>$null
} while ($LASTEXITCODE -ne 0)

Write-Host "✅ PostgreSQL primario está listo!"
```

### 2.3 Verificar Inicialización del Primario
```powershell
# Verificar que las tablas de ejemplo se crearon
docker exec postgresql-primary psql -U admin -d proyecto_db -c "SELECT COUNT(*) as usuarios_iniciales FROM proyecto.usuarios;"

# Verificar que el usuario replicator existe
docker exec postgresql-primary psql -U admin -d proyecto_db -c "SELECT rolname FROM pg_roles WHERE rolname='replicator';"

# Verificar configuración de replicación
docker exec postgresql-primary psql -U admin -d proyecto_db -c "SHOW wal_level;"
```

**Resultado esperado:**
- usuarios_iniciales: 5
- rolname: replicator
- wal_level: replica

## 🔄 Paso 3: Configurar Replicación Manual

### 3.1 Crear y Configurar Nodo Standby
```powershell
# Crear contenedor standby
docker run -d `
  --name postgresql-standby `
  --hostname postgresql-standby `
  --network proyecto_postgresql_postgresql-network `
  -p 5433:5432 `
  -e POSTGRES_HOST_AUTH_METHOD=trust `
  -v postgresql-standby-data:/var/lib/postgresql/data `
  -v ${PWD}/backups:/backups `
  postgres:15

# Esperar a que el contenedor esté disponible
Start-Sleep -Seconds 10

# Configurar standby con pg_basebackup
docker exec postgresql-standby bash -c "
    # Limpiar directorio de datos
    rm -rf /var/lib/postgresql/data/*
    
    # Realizar backup base desde primario
    PGPASSWORD=replica123 pg_basebackup \
        -h postgresql-primary \
        -D /var/lib/postgresql/data \
        -U replicator \
        -v -P -R --wal-method=stream
    
    # Crear signal de standby
    touch /var/lib/postgresql/data/standby.signal
"

# Reiniciar standby para aplicar configuración
docker restart postgresql-standby
Start-Sleep -Seconds 10
```

### 3.2 Crear y Configurar Nodo Readonly
```powershell
# Crear contenedor readonly
docker run -d `
  --name postgresql-readonly `
  --hostname postgresql-readonly `
  --network proyecto_postgresql_postgresql-network `
  -p 5434:5432 `
  -e POSTGRES_HOST_AUTH_METHOD=trust `
  -v postgresql-readonly-data:/var/lib/postgresql/data `
  postgres:15

# Esperar a que el contenedor esté disponible
Start-Sleep -Seconds 10

# Configurar readonly con pg_basebackup
docker exec postgresql-readonly bash -c "
    # Limpiar directorio de datos
    rm -rf /var/lib/postgresql/data/*
    
    # Realizar backup base desde primario
    PGPASSWORD=replica123 pg_basebackup \
        -h postgresql-primary \
        -D /var/lib/postgresql/data \
        -U replicator \
        -v -P -R --wal-method=stream
    
    # Crear signal de standby
    touch /var/lib/postgresql/data/standby.signal
"

# Reiniciar readonly para aplicar configuración
docker restart postgresql-readonly
Start-Sleep -Seconds 10
```

## ✅ Paso 4: Verificar Replicación

### 4.1 Verificar Estado de Contenedores
```powershell
# Ver todos los contenedores
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Debería mostrar:
# postgresql-primary   Up    0.0.0.0:5432->5432/tcp
# postgresql-standby   Up    0.0.0.0:5433->5432/tcp  
# postgresql-readonly  Up    0.0.0.0:5434->5432/tcp
```

### 4.2 Verificar Conectividad de Nodos
```powershell
# Probar conexión al primario
docker exec postgresql-primary pg_isready -U admin -d proyecto_db
Write-Host "✅ Primario: Conectado"

# Probar conexión al standby
docker exec postgresql-standby pg_isready -U admin -d proyecto_db
Write-Host "✅ Standby: Conectado"

# Probar conexión al readonly
docker exec postgresql-readonly pg_isready -U admin -d proyecto_db
Write-Host "✅ Readonly: Conectado"
```

### 4.3 Verificar Estado de Replicación
```powershell
# Ver conexiones de replicación desde el primario
Write-Host "=== Estado de Replicación desde Primario ==="
docker exec postgresql-primary psql -U admin -d proyecto_db -c "
SELECT 
    application_name, 
    client_addr, 
    state, 
    sync_state,
    write_lag,
    flush_lag,
    replay_lag
FROM pg_stat_replication;
"

# Verificar que standby está en recovery mode
Write-Host "`n=== Estado Standby ==="
docker exec postgresql-standby psql -U admin -d proyecto_db -c "SELECT pg_is_in_recovery() as en_recovery;"

# Verificar que readonly está en recovery mode  
Write-Host "`n=== Estado Readonly ==="
docker exec postgresql-readonly psql -U admin -d proyecto_db -c "SELECT pg_is_in_recovery() as en_recovery;"
```

**Resultado esperado:**
- 2 conexiones de replicación activas (standby y readonly)
- state: streaming
- en_recovery: t (true) para standby y readonly

## 🧪 Paso 5: Pruebas Funcionales

### 5.1 Probar Escritura en Primario y Lectura en Réplicas
```powershell
# Insertar datos de prueba en el primario
Write-Host "=== Insertando datos de prueba ==="
docker exec postgresql-primary psql -U admin -d proyecto_db -c "
INSERT INTO proyecto.usuarios (nombre, email) VALUES 
    ('Usuario Prueba 1', 'prueba1@test.com'),
    ('Usuario Prueba 2', 'prueba2@test.com');
    
INSERT INTO proyecto.logs_replicacion (nodo, evento) VALUES 
    ('test', 'Prueba de replicación - $(Get-Date)');
"

# Esperar replicación
Start-Sleep -Seconds 3

# Verificar datos en primario
Write-Host "`n=== Conteo en Primario ==="
docker exec postgresql-primary psql -U admin -d proyecto_db -c "SELECT COUNT(*) as total_usuarios FROM proyecto.usuarios;"

# Verificar datos en standby
Write-Host "`n=== Conteo en Standby ==="
docker exec postgresql-standby psql -U admin -d proyecto_db -c "SELECT COUNT(*) as total_usuarios FROM proyecto.usuarios;"

# Verificar datos en readonly
Write-Host "`n=== Conteo en Readonly ==="
docker exec postgresql-readonly psql -U admin -d proyecto_db -c "SELECT COUNT(*) as total_usuarios FROM proyecto.usuarios;"
```

### 5.2 Probar que NO se puede Escribir en Réplicas
```powershell
# Intentar escribir en standby (debería fallar)
Write-Host "`n=== Probando escritura en Standby (debería fallar) ==="
docker exec postgresql-standby psql -U admin -d proyecto_db -c "
INSERT INTO proyecto.usuarios (nombre, email) VALUES ('No debería funcionar', 'fallo@test.com');
" 2>&1

# Intentar escribir en readonly (debería fallar)
Write-Host "`n=== Probando escritura en Readonly (debería fallar) ==="
docker exec postgresql-readonly psql -U admin -d proyecto_db -c "
INSERT INTO proyecto.usuarios (nombre, email) VALUES ('No debería funcionar', 'fallo@test.com');
" 2>&1
```

**Resultado esperado:** Errores como "cannot execute INSERT in a read-only transaction"

## 💾 Paso 6: Probar Sistema de Backups

### 6.1 Dar Permisos a Scripts (si es necesario)
```powershell
# En PowerShell, no necesitamos chmod, pero verificamos que los scripts existen
ls scripts/backup.sh
```

### 6.2 Crear Backup Completo
```powershell
# Ejecutar backup completo
Write-Host "=== Creando Backup Completo ==="
docker exec postgresql-primary bash /scripts/backup.sh completo

# Verificar que se creó el backup
Write-Host "`n=== Verificando Backup Creado ==="
docker exec postgresql-primary ls -la /backups/full/
```

### 6.3 Crear Backup Incremental
```powershell
# Ejecutar backup incremental
Write-Host "=== Creando Backup Incremental ==="
docker exec postgresql-primary bash /scripts/backup.sh incremental

# Verificar archivos WAL
Write-Host "`n=== Verificando Archivos WAL ==="
docker exec postgresql-primary ls -la /backups/wal_archive/ | head -10
```

### 6.4 Verificar Estado de Backups
```powershell
# Ver estado general de backups
Write-Host "=== Estado General de Backups ==="
docker exec postgresql-primary bash /scripts/backup.sh estado
```

## 🔄 Paso 7: Probar Failover Manual

### 7.1 Verificar Estado Antes del Failover
```powershell
Write-Host "=== Estado ANTES del Failover ==="
docker exec postgresql-primary psql -U admin -d proyecto_db -c "SELECT application_name, state FROM pg_stat_replication;"
```

### 7.2 Simular Caída del Primario
```powershell
Write-Host "`n=== Simulando Caída del Primario ==="
# Detener el contenedor primario
docker stop postgresql-primary

# Esperar unos segundos
Start-Sleep -Seconds 5
```

### 7.3 Promover Standby a Primario
```powershell
Write-Host "`n=== Promoviendo Standby a Primario ==="
# Promover el standby
docker exec postgresql-standby pg_ctl promote -D /var/lib/postgresql/data

# Esperar a que la promoción se complete
Start-Sleep -Seconds 10

# Verificar que el standby ya no está en recovery
Write-Host "`n=== Verificando Promoción ==="
docker exec postgresql-standby psql -U admin -d proyecto_db -c "SELECT pg_is_in_recovery() as en_recovery;"
```

### 7.4 Probar Escritura en Nuevo Primario
```powershell
Write-Host "`n=== Probando Escritura en Nuevo Primario ==="
docker exec postgresql-standby psql -U admin -d proyecto_db -c "
INSERT INTO proyecto.usuarios (nombre, email) VALUES ('Post-Failover', 'failover@test.com');
INSERT INTO proyecto.logs_replicacion (nodo, evento) VALUES ('standby-promoted', 'Failover completado exitosamente');
SELECT COUNT(*) as total_usuarios_post_failover FROM proyecto.usuarios;
"
```

### 7.5 Restaurar Estado Original (Opcional)
```powershell
Write-Host "`n=== Restaurando Estado Original ==="
# Detener todos los contenedores
docker stop postgresql-standby postgresql-readonly 2>$null

# Reiniciar configuración original
docker-compose down
docker-compose up -d

# Esperar a que esté listo
do {
    Start-Sleep -Seconds 5
    $ready = docker exec postgresql-primary pg_isready -U admin -d proyecto_db 2>$null
} while ($LASTEXITCODE -ne 0)

Write-Host "✅ Estado original restaurado"
```

## 📊 Paso 8: Verificaciones Finales y Monitoreo

### 8.1 Conexiones Externas (desde tu máquina)
```powershell
# Si tienes psql instalado localmente, puedes conectarte:
Write-Host "=== Información de Conexión Externa ==="
Write-Host "Primario:  psql -h localhost -p 5432 -U admin -d proyecto_db"
Write-Host "Standby:   psql -h localhost -p 5433 -U admin -d proyecto_db" 
Write-Host "Readonly:  psql -h localhost -p 5434 -U admin -d proyecto_db"
Write-Host ""
Write-Host "Usuario: admin"
Write-Host "Contraseña: admin123"
```

### 8.2 Monitoreo Continuo (Opcional)
```powershell
# Script para monitoreo básico en bucle
Write-Host "=== Iniciando Monitoreo (Ctrl+C para salir) ==="
while ($true) {
    Clear-Host
    Write-Host "=== Monitoreo Clúster PostgreSQL - $(Get-Date) ==="
    
    # Estado de contenedores
    Write-Host "`n--- Estado Contenedores ---"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | findstr postgresql
    
    # Estado de replicación
    Write-Host "`n--- Estado Replicación ---"
    docker exec postgresql-primary psql -U admin -d proyecto_db -c "SELECT application_name, state, write_lag FROM pg_stat_replication;" 2>$null
    
    # Uso de espacio
    Write-Host "`n--- Uso de Espacio Backups ---"
    docker exec postgresql-primary du -sh /backups/* 2>$null
    
    Start-Sleep -Seconds 15
}
```

## 🎯 Resumen de Comandos Rápidos

### Comandos de Estado
```powershell
# Estado rápido de todo
docker ps --format "table {{.Names}}\t{{.Status}}"
docker exec postgresql-primary psql -U admin -d proyecto_db -c "SELECT COUNT(*) FROM pg_stat_replication;"

# Logs de errores
docker logs postgresql-primary --tail 20
docker logs postgresql-standby --tail 20
```

### Comandos de Backup
```powershell
# Backup rápido
docker exec postgresql-primary bash /scripts/backup.sh completo

# Ver backups
docker exec postgresql-primary ls -la /backups/full/
```

### Comandos de Limpieza
```powershell
# Limpiar todo
docker-compose down
docker volume rm proyecto_postgresql_postgresql-primary-data -f
docker container rm postgresql-standby postgresql-readonly -f
docker volume rm postgresql-standby-data postgresql-readonly-data -f
```

## ⚠️ Problemas Comunes y Soluciones

### Problema 1: Docker no responde
```powershell
# Reiniciar Docker Desktop
# Desde el menú de Docker Desktop: "Restart Docker"
# O desde PowerShell como admin:
Restart-Service docker
```

### Problema 2: Puerto ocupado
```powershell
# Ver qué está usando el puerto
netstat -ano | findstr :5432
# Matar proceso si es necesario (cambiar PID)
Stop-Process -Id <PID> -Force
```

### Problema 3: Contenedor no inicia
```powershell
# Ver logs detallados
docker logs postgresql-primary
# Revisar permisos de volúmenes
docker volume inspect proyecto_postgresql_postgresql-primary-data
```

### Problema 4: Replicación no funciona
```powershell
# Verificar red Docker
docker network ls
docker network inspect proyecto_postgresql_postgresql-network

# Verificar conectividad entre contenedores
docker exec postgresql-standby ping postgresql-primary
```

## ✅ Checklist de Verificación Final

- [ ] Contenedor primario levantado y funcional
- [ ] Tablas de ejemplo creadas (5 usuarios iniciales)
- [ ] Usuario replicator creado
- [ ] Contenedores standby y readonly funcionando
- [ ] Replicación streaming activa (2 conexiones en pg_stat_replication)
- [ ] Inserción en primario se replica a secundarios
- [ ] Escritura falla en réplicas (solo lectura)
- [ ] Backup completo se ejecuta sin errores
- [ ] Archivos WAL se generan en /backups/wal_archive/
- [ ] Failover manual funciona (standby se convierte en primario)
- [ ] Conexiones externas funcionan (puertos 5432, 5433, 5434)

## 🎉 ¡Éxito!

Si completaste todos los pasos y las verificaciones pasaron, tienes un clúster PostgreSQL completamente funcional con:

- ✅ Replicación streaming en tiempo real
- ✅ Failover manual operativo  
- ✅ Sistema de backups automatizado
- ✅ Monitoreo básico funcionando
- ✅ Alta disponibilidad configurada

**Próximos pasos recomendados:**
1. Configurar backups automáticos con cron
2. Implementar monitoreo avanzado (Grafana)
3. Endurecer configuración para producción
4. Probar recovery desde backups (PITR)