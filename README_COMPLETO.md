# Proyecto PostgreSQL - Clúster con Replicación Streaming

Este proyecto implementa un clúster de PostgreSQL de 3 nodos con replicación streaming, failover manual y estrategia completa de respaldos.

## 🏗️ Arquitectura

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   PRIMARY       │    │    STANDBY      │    │   READONLY      │
│   puerto 5432   │───▶│   puerto 5433   │    │   puerto 5434   │
│ (Lectura/Escr.) │    │ (Solo Lectura)  │◀───│ (Solo Lectura)  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                        │                        │
         └────────────────────────┼────────────────────────┘
                                  │
                         ┌─────────────────┐
                         │   WAL ARCHIVE   │
                         │    (Backups)    │
                         └─────────────────┘
```

## 🚀 Inicio Rápido

### Prerrequisitos
- Docker Desktop instalado y ejecutándose
- PowerShell (Windows) o Bash (Linux/macOS)
- Git (opcional)

### Para Windows:
```powershell
# 1. Clonar el repositorio (o descargar)
git clone <repository-url>
cd proyecto_postgresql

# 2. Levantar el clúster (solo nodo primario)
docker-compose up -d

# 3. Usar el menú interactivo
.\comandos.ps1 menu

# 4. Para configurar replicación manualmente
.\comandos.ps1 replicacion-manual
```

### Para Linux/macOS:
```bash
# 1. Dar permisos de ejecución
chmod +x scripts/*.sh
chmod +x setup_replication_manual.sh

# 2. Levantar el clúster
docker-compose up -d

# 3. Configurar replicación manualmente
./setup_replication_manual.sh
```

## 📁 Estructura del Proyecto

```
proyecto_postgresql/
├── docker-compose.yml          # Orquestación de contenedores
├── comandos.ps1               # Menú interactivo para Windows
├── setup_replication_manual.sh # Script manual de replicación (Linux)
├── setup_replication_manual.ps1 # Script manual de replicación (Windows)
├── primary/                   # Configuración nodo primario
│   ├── init-primary.sh
│   ├── postgresql.conf
│   └── pg_hba.conf
├── standby/                   # Configuración nodo standby
│   ├── init-standby.sh
│   ├── postgresql.conf
│   ├── pg_hba.conf
│   └── setup-replica.sh
├── readonly/                  # Configuración nodo readonly
│   ├── init-readonly.sh
│   ├── postgresql.conf
│   ├── pg_hba.conf
│   └── setup-replica.sh
├── scripts/                   # Scripts de administración
│   ├── backup.sh             # Respaldos automatizados
│   ├── failover.sh           # Failover manual
│   ├── monitor.sh            # Monitoreo
│   ├── setup.sh              # Configuración inicial
│   └── setup_cron.sh         # Tareas programadas
└── backups/                   # Almacén de respaldos
    ├── full/                 # Backups completos
    ├── incremental/          # Backups incrementales
    └── wal_archive/          # Archivos WAL
```

## 🔧 Configuración Actual

### Nodo Primario (Funcional)
- **Puerto**: 5432
- **Usuario**: admin
- **Password**: admin123
- **Base de datos**: proyecto_db
- **Estado**: ✅ Completamente funcional
- **Características**:
  - Lectura y escritura
  - WAL archiving configurado
  - Usuarios de replicación creados
  - Datos de ejemplo cargados

### Nodos Standby y Readonly
- **Estado**: ⚠️ Configuración manual requerida
- **Puertos**: 5433 (standby), 5434 (readonly)
- **Características**:
  - Solo lectura
  - Replicación streaming desde primario
  - Configuración automática con scripts manuales

## 🎮 Uso del Sistema

### Menú Interactivo (Windows)
```powershell
.\comandos.ps1 menu
```

### Comandos Directos
```powershell
# Levantar clúster
.\comandos.ps1 iniciar

# Ver estado
.\comandos.ps1 estado

# Monitoreo continuo
.\comandos.ps1 monitor

# Configurar replicación manual
.\comandos.ps1 replicacion-manual

# Crear backup completo
.\comandos.ps1 backup-completo

# Failover manual
.\comandos.ps1 failover

# Conectar con psql
.\comandos.ps1 conectar
```

## 🔄 Configuración de Replicación

### Método Automático (Recomendado)
1. Asegurar que el nodo primario esté ejecutándose
2. Ejecutar el script de configuración:
   ```powershell
   # Windows
   .\setup_replication_manual.ps1
   
   # Linux/macOS
   ./setup_replication_manual.sh
   ```
3. Seleccionar opciones del menú según necesidades

### Método Manual
```bash
# 1. Crear contenedores standby/readonly
docker run -d --name postgresql-standby --network proyecto_postgresql_postgresql-network -p 5433:5432 -e POSTGRES_HOST_AUTH_METHOD=trust postgres:15

# 2. Realizar pg_basebackup
docker exec -u postgres postgresql-standby bash -c "
    rm -rf /var/lib/postgresql/data/*
    PGPASSWORD=replica123 pg_basebackup -h postgresql-primary -D /var/lib/postgresql/data -U replicator -v -P -R --wal-method=stream
    touch /var/lib/postgresql/data/standby.signal
    pg_ctl start -D /var/lib/postgresql/data
"
```

## 💾 Estrategia de Respaldos

### Backups Completos
- **Frecuencia**: Semanal (domingos)
- **Método**: pg_basebackup con compresión
- **Almacenamiento**: `/backups/full/`
- **Comando**: `.\comandos.ps1 backup-completo`

### Backups Incrementales
- **Frecuencia**: Diario
- **Método**: Archivado WAL
- **Almacenamiento**: `/backups/incremental/`
- **Comando**: `.\comandos.ps1 backup-incremental`

### Retención
- **Backups completos**: 4 semanas
- **Backups incrementales**: 7 días
- **Archivos WAL**: 7 días

## 🚨 Procedimientos de Emergencia

### Failover Manual
1. Verificar estado del primario:
   ```powershell
   .\comandos.ps1 estado
   ```
2. Ejecutar failover:
   ```powershell
   .\comandos.ps1 failover
   ```
3. El standby será promovido a primario
4. Actualizar aplicaciones al nuevo puerto (5433)

### Recuperación desde Backup
```bash
# 1. Detener contenedores afectados
docker-compose down

# 2. Restaurar desde backup completo
docker run --rm -v postgresql-primary-data:/data -v ./backups:/backups postgres:15 bash -c "
    cd /data && tar -xzf /backups/full/full_backup_YYYYMMDD_HHMMSS.tar.gz
"

# 3. Aplicar WAL files para point-in-time recovery
# (proceso específico según necesidades)

# 4. Reiniciar servicios
docker-compose up -d
```

## 🔍 Monitoreo

### Estado de Replicación
```sql
-- En el nodo primario
SELECT application_name, client_addr, state, sync_state 
FROM pg_stat_replication;

-- En nodos standby/readonly
SELECT pg_is_in_recovery();
```

### Logs del Sistema
```powershell
# Ver logs específicos
.\comandos.ps1 logs

# Monitoreo continuo
.\comandos.ps1 monitor
```

### Métricas Importantes
- Lag de replicación
- Espacio en disco (especialmente WAL)
- Conexiones activas
- Estado de archivado WAL

## 🔐 Seguridad

### Configuración Actual
- **Autenticación**: Trust (desarrollo)
- **Conexiones**: Solo red Docker
- **Usuario replicación**: `replicator`
- **Acceso externo**: Limitado a puertos específicos

### Para Producción (Recomendaciones)
1. Cambiar autenticación de `trust` a `md5` o `scram-sha-256`
2. Configurar SSL/TLS para replicación
3. Implementar firewall rules
4. Rotar passwords regularmente
5. Configurar pg_hba.conf restrictivo

## 🧪 Datos de Prueba

El sistema incluye datos de ejemplo en `proyecto_db`:
- **Esquema**: `proyecto`
- **Tablas**: `usuarios`, `logs_replicacion`
- **Datos**: 5 usuarios de ejemplo
- **Logs**: Registro de eventos del sistema

### Consultas de Ejemplo
```sql
-- Ver usuarios
SELECT * FROM proyecto.usuarios;

-- Ver logs de replicación
SELECT * FROM proyecto.logs_replicacion ORDER BY fecha DESC;

-- Insertar datos de prueba
INSERT INTO proyecto.usuarios (nombre, email) 
VALUES ('Test User', 'test@example.com');
```

## 🔧 Troubleshooting

### Problemas Comunes

**1. Contenedores no inician**
```powershell
# Verificar Docker
docker --version
docker-compose --version

# Ver logs
docker-compose logs
```

**2. Replicación no funciona**
```powershell
# Verificar estado de red
docker network ls
docker network inspect proyecto_postgresql_postgresql-network

# Verificar configuración
docker exec postgresql-primary cat /var/lib/postgresql/data/postgresql.conf | grep wal_level
```

**3. No se puede conectar**
```powershell
# Verificar puertos
docker-compose ps

# Probar conexión
docker exec postgresql-primary pg_isready -U admin
```

**4. Error de permisos**
```bash
# Dar permisos a scripts
chmod +x scripts/*.sh
chmod +x *.sh
```

### Logs Útiles
```bash
# Logs de PostgreSQL dentro del contenedor
docker exec postgresql-primary tail -f /var/lib/postgresql/data/log/postgresql-*.log

# Logs de Docker
docker logs postgresql-primary

# Logs de replicación
docker exec postgresql-primary psql -U admin -d proyecto_db -c "SELECT * FROM pg_stat_replication;"
```

## 📚 Referencias

- [PostgreSQL Streaming Replication](https://www.postgresql.org/docs/15/warm-standby.html)
- [Docker Compose](https://docs.docker.com/compose/)
- [PostgreSQL High Availability](https://www.postgresql.org/docs/15/high-availability.html)
- [WAL Archiving](https://www.postgresql.org/docs/15/continuous-archiving.html)

## 🤝 Contribuciones

Este es un proyecto académico para aprendizaje de administración de bases de datos. 
Sugerencias y mejoras son bienvenidas.

---

## 📋 Estado del Proyecto

- ✅ **Nodo Primario**: Completamente funcional
- ⚠️ **Replicación**: Configuración manual disponible
- ✅ **Backups**: Implementados y funcionales
- ✅ **Monitoreo**: Scripts completos
- ✅ **Failover**: Procedimiento manual listo
- ✅ **Documentación**: Completa

**Último Update**: 2024-12-19